module Application.Helper.Export where

import Application.Helper.Controller
import Application.Helper.Pay (ensureCurrentVenuePayConfigSnapshot)
import Control.Monad (void)
import qualified Data.Aeson as Aeson
import Data.Coerce (coerce)
import qualified Data.List as List
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Data.Time.Calendar (Day)
import Data.Time.Clock (NominalDiffTime, UTCTime, addUTCTime, getCurrentTime)
import Data.Time.Format (defaultTimeLocale, formatTime)
import Data.Time.LocalTime (TimeOfDay)
import Generated.Types
import IHP.ControllerPrelude

data ExportJobType
    = ApprovedTimesheetsCsv
    deriving (Eq, Show)

data ExportJobStatus
    = ExportPending
    | ExportReady
    | ExportExpired
    deriving (Eq, Show)

allExportJobTypeValues :: [Text]
allExportJobTypeValues = ["approved_timesheets_csv"]

allExportJobStatusValues :: [Text]
allExportJobStatusValues = ["pending", "ready", "expired"]

exportJobTypeToText :: ExportJobType -> Text
exportJobTypeToText ApprovedTimesheetsCsv = "approved_timesheets_csv"

parseExportJobType :: Text -> Maybe ExportJobType
parseExportJobType "approved_timesheets_csv" = Just ApprovedTimesheetsCsv
parseExportJobType _                         = Nothing

exportJobStatusToText :: ExportJobStatus -> Text
exportJobStatusToText ExportPending = "pending"
exportJobStatusToText ExportReady   = "ready"
exportJobStatusToText ExportExpired = "expired"

parseExportJobStatus :: Text -> Maybe ExportJobStatus
parseExportJobStatus "pending" = Just ExportPending
parseExportJobStatus "ready"   = Just ExportReady
parseExportJobStatus "expired" = Just ExportExpired
parseExportJobStatus _         = Nothing

browserDownloadMethod :: Text
browserDownloadMethod = "browser_download"

exportSchemaVersion :: Int
exportSchemaVersion = 1

exportExpirySeconds :: NominalDiffTime
exportExpirySeconds = 60 * 60 * 24

requestApprovedTimesheetsCsvExport ::
    (?context :: ControllerContext, ?modelContext :: ModelContext) =>
    Day ->
    Day ->
    IO ExportJob
requestApprovedTimesheetsCsvExport rangeStart rangeEnd = withTransaction do
    now <- getCurrentTime
    let expiresAt = addUTCTime exportExpirySeconds now
    let exportType = exportJobTypeToText ApprovedTimesheetsCsv
    _ <- ensureCurrentVenuePayConfigSnapshot
    let initialScope =
            Aeson.object
                [ "rangeStart" Aeson..= rangeStart
                , "rangeEnd" Aeson..= rangeEnd
                , "approvedOnly" Aeson..= True
                ]
    exportJob <-
        newRecord @ExportJob
            |> set #venueId (unpackId currentVenueId)
            |> set #requestedByUserId (unpackId (get #id currentUser))
            |> set #exportType exportType
            |> set #status (exportJobStatusToText ExportPending)
            |> set #schemaVersion exportSchemaVersion
            |> set #rangeStart (Just rangeStart)
            |> set #rangeEnd (Just rangeEnd)
            |> set #scope initialScope
            |> set #deliveryMethod browserDownloadMethod
            |> set #destinationMetadata (Aeson.object ["requestedVia" Aeson..= requestAuditSourceChannel])
            |> set #expiresAt expiresAt
            |> createRecord

    entries <- fetchApprovedTimesheetEntries rangeStart rangeEnd
    staffById <- fetchStaffMap entries
    approversById <- fetchApproverMap entries
    snapshotVersionsByEntryId <- fetchSnapshotVersionsForEntries entries
    let snapshotVersions = List.sort (List.nub (Map.elems snapshotVersionsByEntryId))
    let exportSnapshotVersion =
            case snapshotVersions of
                []             -> Nothing
                [versionLabel] -> Just versionLabel
                _              -> Just "mixed"
    let csvContents = renderApprovedTimesheetCsv entries staffById approversById snapshotVersionsByEntryId
    let fileName = buildApprovedTimesheetExportFileName rangeStart rangeEnd
    let finalScope =
            Aeson.object
                [ "rangeStart" Aeson..= rangeStart
                , "rangeEnd" Aeson..= rangeEnd
                , "approvedOnly" Aeson..= True
                , "entryCount" Aeson..= length entries
                , "snapshotVersions" Aeson..= snapshotVersions
                ]
    exportJob <-
        exportJob
            |> set #status (exportJobStatusToText ExportReady)
            |> set #payConfigSnapshotVersion exportSnapshotVersion
            |> set #scope finalScope
            |> set #fileName (Just fileName)
            |> set #contentType (Just "text/csv; charset=utf-8")
            |> set #fileContents (Just csvContents)
            |> updateRecord

    void $ recordCurrentUserAuditEvent
        "export_generated"
        "export_jobs"
        (unpackId (get #id exportJob))
        (Aeson.object
            [ "exportType" Aeson..= exportType
            , "rangeStart" Aeson..= rangeStart
            , "rangeEnd" Aeson..= rangeEnd
            , "entryCount" Aeson..= length entries
            , "payConfigSnapshotVersion" Aeson..= exportSnapshotVersion
            , "deliveryMethod" Aeson..= exportJob.deliveryMethod
            ]
        )

    pure exportJob

expireCurrentVenueExportJobs :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO ()
expireCurrentVenueExportJobs = do
    now <- getCurrentTime
    exportJobs <- query @ExportJob
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> fetch

    forM_ exportJobs \exportJob ->
        when (shouldExpireExportJob now exportJob) do
            exportJob
                |> set #status (exportJobStatusToText ExportExpired)
                |> updateRecordDiscardResult

fetchCurrentVenueExportJobs :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO [ExportJob]
fetchCurrentVenueExportJobs = do
    expireCurrentVenueExportJobs
    query @ExportJob
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> orderByDesc #createdAt
        |> fetch

authorizeExportDownload ::
    (?context :: ControllerContext, ?modelContext :: ModelContext) =>
    Id ExportJob ->
    UUID ->
    IO ExportJob
authorizeExportDownload exportJobId downloadToken = do
    exportJob <- fetch exportJobId
    ensureRecordInCurrentVenue exportJob.venueId
    accessDeniedUnless (exportJob.downloadToken == downloadToken)

    now <- getCurrentTime
    when (shouldExpireExportJob now exportJob) do
        exportJob
            |> set #status (exportJobStatusToText ExportExpired)
            |> updateRecordDiscardResult
        accessDeniedUnless False

    accessDeniedUnless (exportJob.status == exportJobStatusToText ExportReady)
    accessDeniedUnless (isJust exportJob.fileContents)
    pure exportJob

recordExportDownload ::
    (?context :: ControllerContext, ?modelContext :: ModelContext) =>
    ExportJob ->
    IO ExportJob
recordExportDownload exportJob = withTransaction do
    now <- getCurrentTime
    exportJob <-
        exportJob
            |> set #downloadedAt (Just now)
            |> set #downloadedByUserId (Just (unpackId (get #id currentUser)))
            |> updateRecord

    void $ recordCurrentUserAuditEvent
        "export_downloaded"
        "export_jobs"
        (unpackId (get #id exportJob))
        (Aeson.object
            [ "exportType" Aeson..= exportJob.exportType
            , "generatedFileId" Aeson..= exportJob.generatedFileId
            , "deliveryMethod" Aeson..= exportJob.deliveryMethod
            ]
        )

    pure exportJob

buildApprovedTimesheetExportFileName :: Day -> Day -> Text
buildApprovedTimesheetExportFileName rangeStart rangeEnd =
    "approved-timesheets-" <> tshow rangeStart <> "-to-" <> tshow rangeEnd <> ".csv"

renderApprovedTimesheetCsv ::
    [TimesheetEntry] ->
    Map.Map UUID Staff ->
    Map.Map UUID User ->
    Map.Map UUID Text ->
    Text
renderApprovedTimesheetCsv entries staffById approversById snapshotVersionsByEntryId =
    Text.unlines (csvHeader : map renderRow entries)
    where
        csvHeader =
            Text.intercalate ","
                [ "worked_on"
                , "staff_name"
                , "start_time"
                , "end_time"
                , "break_minutes"
                , "pay_config_snapshot_version"
                , "approved_at"
                , "approved_by_email"
                ]

        renderRow entry =
            Text.intercalate ","
                [ csvCell (tshow entry.workedOn)
                , csvCell (staffDisplayName entry.staffId)
                , csvCell (formatTimeOfDay entry.startTime)
                , csvCell (formatTimeOfDay entry.endTime)
                , csvCell (tshow entry.breakMinutes)
                , csvCell (fromMaybe "" (entry.payConfigSnapshotId >>= (`Map.lookup` snapshotVersionsByEntryId)))
                , csvCell (maybe "" formatUtc entry.approvedAt)
                , csvCell (maybe "" (.email) (entry.approvedByUserId >>= (`Map.lookup` approversById)))
                ]

        staffDisplayName staffId =
            case Map.lookup staffId staffById of
                Just staff -> staff.lastName <> ", " <> staff.firstName
                Nothing    -> "Unknown staff"

fetchApprovedTimesheetEntries ::
    (?context :: ControllerContext, ?modelContext :: ModelContext) =>
    Day ->
    Day ->
    IO [TimesheetEntry]
fetchApprovedTimesheetEntries rangeStart rangeEnd =
    query @TimesheetEntry
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> filterWhere (#isApproved, True)
        |> filterWhereIn (#workedOn, [rangeStart .. rangeEnd])
        |> orderByAsc #workedOn
        |> orderByAsc #startTime
        |> fetch

fetchStaffMap :: (?modelContext :: ModelContext) => [TimesheetEntry] -> IO (Map.Map UUID Staff)
fetchStaffMap entries =
    if null staffIds
        then pure Map.empty
        else do
            staff <- query @Staff |> filterWhereIn (#id, map Id staffIds) |> fetch
            pure (Map.fromList (map (\staffMember -> (coerce (get #id staffMember), staffMember)) staff))
    where
        staffIds = List.nub (map (.staffId) entries)

fetchApproverMap :: (?modelContext :: ModelContext) => [TimesheetEntry] -> IO (Map.Map UUID User)
fetchApproverMap entries =
    if null approverIds
        then pure Map.empty
        else do
            users <- query @User |> filterWhereIn (#id, map Id approverIds) |> fetch
            pure (Map.fromList (map (\user -> (coerce (get #id user), user)) users))
    where
        approverIds = List.nub (mapMaybe (.approvedByUserId) entries)

fetchSnapshotVersionsForEntries :: (?modelContext :: ModelContext) => [TimesheetEntry] -> IO (Map.Map UUID Text)
fetchSnapshotVersionsForEntries entries =
    if null snapshotIds
        then pure Map.empty
        else do
            snapshots <- query @PayConfigSnapshot |> filterWhereIn (#id, map Id snapshotIds) |> fetch
            pure (Map.fromList (map (\snapshot -> (coerce (get #id snapshot), snapshot.versionLabel)) snapshots))
    where
        snapshotIds = List.nub (mapMaybe (.payConfigSnapshotId) entries)

shouldExpireExportJob :: UTCTime -> ExportJob -> Bool
shouldExpireExportJob now exportJob =
    exportJob.status /= exportJobStatusToText ExportExpired
        && exportJob.expiresAt <= now

formatTimeOfDay :: TimeOfDay -> Text
formatTimeOfDay timeOfDay = Text.pack (formatTime defaultTimeLocale "%H:%M" timeOfDay)

formatUtc :: UTCTime -> Text
formatUtc timestamp = Text.pack (formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S UTC" timestamp)

csvCell :: Text -> Text
csvCell value
    | Text.any (`elem` [',', '"', '\n', '\r']) value =
        "\"" <> Text.replace "\"" "\"\"" value <> "\""
    | otherwise = value
