module Application.Helper.Pay where

import Data.Aeson ((.:), (.:?))
import qualified Data.Aeson as Aeson
import qualified Data.Map.Strict as Map
import qualified Data.Scientific as Scientific
import qualified Data.Text as Text
import Data.Text.Encoding (encodeUtf8)
import Data.Time.Calendar (Day)
import qualified Database.PostgreSQL.Simple as PG
import Generated.Types
import IHP.ModelSupport (ModelContext, sqlQueryScalar, unpackId)
import IHP.Prelude

data PaySegment = PaySegment
    { segment           :: !Text
    , minutes           :: !Int
    , multiplier        :: !Scientific.Scientific
    , dayRuleMultiplier :: !(Maybe Scientific.Scientific)
    , weekendMultiplier :: !(Maybe Scientific.Scientific)
    }
    deriving (Eq, Show)

instance Aeson.FromJSON PaySegment where
    parseJSON = Aeson.withObject "PaySegment" \obj ->
        PaySegment
            <$> obj .: "segment"
            <*> obj .: "minutes"
            <*> obj .: "multiplier"
            <*> obj .:? "dayRuleMultiplier"
            <*> obj .:? "weekendMultiplier"

data PayTotals = PayTotals
    { paidMinutes :: !Int
    , totalAmount :: !Scientific.Scientific
    }
    deriving (Eq, Show)

instance Aeson.FromJSON PayTotals where
    parseJSON = Aeson.withObject "PayTotals" \obj ->
        PayTotals
            <$> obj .: "paidMinutes"
            <*> obj .: "totalAmount"

data TimesheetPayResult = TimesheetPayResult
    { entryId  :: !Text
    , segments :: ![PaySegment]
    , totals   :: !PayTotals
    }
    deriving (Eq, Show)

instance Aeson.FromJSON TimesheetPayResult where
    parseJSON = Aeson.withObject "TimesheetPayResult" \obj ->
        TimesheetPayResult
            <$> obj .: "entryId"
            <*> obj .: "segments"
            <*> obj .: "totals"

data TimesheetPaySummary = TimesheetPaySummary
    { paidMinutes          :: !Int
    , totalAmount          :: !Scientific.Scientific
    , segmentCount         :: !Int
    , weekendApplied       :: !Bool
    , hasStackedMultiplier :: !Bool
    }
    deriving (Eq, Show)

decodeTimesheetPayResult :: Text -> Either Text TimesheetPayResult
decodeTimesheetPayResult payload =
    case Aeson.eitherDecodeStrict' (encodeUtf8 payload) of
        Left err -> Left ("Failed to decode calculate_timesheet_pay payload: " <> Text.pack err)
        Right value -> Right value

decodeTimesheetPayResults :: Text -> Either Text [TimesheetPayResult]
decodeTimesheetPayResults payload =
    case Aeson.eitherDecodeStrict' (encodeUtf8 payload) of
        Left err -> Left ("Failed to decode calculate_timesheet_pay_range payload: " <> Text.pack err)
        Right value -> Right value

timesheetEntryIdKey :: Id TimesheetEntry -> Text
timesheetEntryIdKey entryId = tshow (unpackId entryId)

buildTimesheetPaySummary :: TimesheetPayResult -> TimesheetPaySummary
buildTimesheetPaySummary result =
    TimesheetPaySummary
        { paidMinutes = result.totals.paidMinutes
        , totalAmount = result.totals.totalAmount
        , segmentCount = length result.segments
        , weekendApplied = any hasWeekend result.segments
        , hasStackedMultiplier = any hasStacked result.segments
        }
    where
        hasWeekend segment = maybe False (> 1) segment.weekendMultiplier
        hasStacked segment = maybe False (> 1) segment.weekendMultiplier && maybe False (/= 1) segment.dayRuleMultiplier

buildTimesheetPaySummariesByEntryId :: [TimesheetPayResult] -> Map.Map Text TimesheetPaySummary
buildTimesheetPaySummariesByEntryId results =
    Map.fromList (map (\result -> (result.entryId, buildTimesheetPaySummary result)) results)

fetchTimesheetPay :: (?modelContext :: ModelContext) => Id TimesheetEntry -> IO (Either Text TimesheetPayResult)
fetchTimesheetPay entryId = do
    payload :: Text <- sqlQueryScalar "SELECT calculate_timesheet_pay(?)::text" (PG.Only (unpackId entryId))
    pure (decodeTimesheetPayResult payload)

fetchTimesheetPayRange :: (?modelContext :: ModelContext) => UUID -> Day -> Day -> IO (Either Text [TimesheetPayResult])
fetchTimesheetPayRange staffId fromDate toDate = do
    payload :: Text <- sqlQueryScalar "SELECT calculate_timesheet_pay_range(?, ?, ?)::text" (staffId, fromDate, toDate)
    pure (decodeTimesheetPayResults payload)

fetchTimesheetPaySummariesForEntries :: (?modelContext :: ModelContext) => [TimesheetEntry] -> IO (Map.Map Text TimesheetPaySummary)
fetchTimesheetPaySummariesForEntries entries = do
    let groupedEntries = groupByStaff entries
    resultMaps <- forM (Map.toList groupedEntries) \(staffId, staffEntries) -> do
        let fromDate = minimum (map (.workedOn) staffEntries)
        let toDate = maximum (map (.workedOn) staffEntries)
        payResults <- fetchTimesheetPayRange staffId fromDate toDate
        case payResults of
            Left _        -> pure Map.empty
            Right results -> pure (buildTimesheetPaySummariesByEntryId results)
    pure (Map.unions resultMaps)
    where
        groupByStaff :: [TimesheetEntry] -> Map.Map UUID [TimesheetEntry]
        groupByStaff =
            foldl' (\acc entry -> Map.insertWith (<>) entry.staffId [entry] acc) Map.empty
