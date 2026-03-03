module Application.Helper.Controller where

import Data.Coerce (coerce)
import Data.List (find, sortOn)
import Data.Time.Calendar (Day, addDays, diffDays)
import Data.Time.Clock (UTCTime (..), getCurrentTime)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Data.Time.LocalTime (TimeOfDay (..))
import Generated.Types
import IHP.Controller.Context (maybeFromContext, putContext)
import IHP.ControllerPrelude
import System.IO.Unsafe (unsafePerformIO)
import Web.Routes ()
import Web.Types (ProfilesController (EditProfileAction))

-- Here you can add functions which are available in all your controllers

currentVenueSessionKey :: ByteString
currentVenueSessionKey = "currentVenueId"

fetchVenueConfig :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO VenueConfig
fetchVenueConfig =
    query @VenueConfig
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> fetchOne

data UserRole
    = StaffRole
    | ManagerRole
    | AdminRole
    deriving (Eq, Show)

data VenueRole
    = WorkerRole
    | ManagerRole'
    | VenueAdminRole
    | VenueOwnerRole
    deriving (Eq, Ord, Show, Enum, Bounded)

data LeaveRequestStatus
    = LeavePending
    | LeaveApproved
    | LeaveDenied
    deriving (Eq, Show)

allUserRoleValues :: [Text]
allUserRoleValues = ["staff", "manager", "admin"]

allVenueRoleValues :: [Text]
allVenueRoleValues = ["worker", "manager", "venue_admin", "venue_owner"]

allLeaveRequestStatusValues :: [Text]
allLeaveRequestStatusValues = ["pending", "approved", "denied"]

parseUserRole :: Text -> Maybe UserRole
parseUserRole "staff"   = Just StaffRole
parseUserRole "manager" = Just ManagerRole
parseUserRole "admin"   = Just AdminRole
parseUserRole _         = Nothing

parseVenueRole :: Text -> Maybe VenueRole
parseVenueRole "worker"      = Just WorkerRole
parseVenueRole "manager"     = Just ManagerRole'
parseVenueRole "venue_admin" = Just VenueAdminRole
parseVenueRole "venue_owner" = Just VenueOwnerRole
parseVenueRole _             = Nothing

parseLeaveRequestStatus :: Text -> Maybe LeaveRequestStatus
parseLeaveRequestStatus "pending"  = Just LeavePending
parseLeaveRequestStatus "approved" = Just LeaveApproved
parseLeaveRequestStatus "denied"   = Just LeaveDenied
parseLeaveRequestStatus _          = Nothing

userRoleToText :: UserRole -> Text
userRoleToText StaffRole   = "staff"
userRoleToText ManagerRole = "manager"
userRoleToText AdminRole   = "admin"

venueRoleToText :: VenueRole -> Text
venueRoleToText WorkerRole     = "worker"
venueRoleToText ManagerRole'   = "manager"
venueRoleToText VenueAdminRole = "venue_admin"
venueRoleToText VenueOwnerRole = "venue_owner"

bootstrapRegistrationRole :: Int -> UserRole
bootstrapRegistrationRole existingUserCount
    | existingUserCount <= 0 = AdminRole
    | otherwise = StaffRole

leaveRequestStatusToText :: LeaveRequestStatus -> Text
leaveRequestStatusToText LeavePending  = "pending"
leaveRequestStatusToText LeaveApproved = "approved"
leaveRequestStatusToText LeaveDenied   = "denied"

requiredProfileFieldsCompleted :: Text -> Text -> Bool
requiredProfileFieldsCompleted firstName lastName =
    not (any isEmpty [firstName, lastName])

isOperationallyActive :: User -> Bool
isOperationallyActive user = user.isProfileCompleted

ensureProfileCompleted :: (?context :: ControllerContext) => IO ()
ensureProfileCompleted =
    unless (isOperationallyActive currentUser) do
        setErrorMessage "Please complete your profile to continue."
        redirectTo EditProfileAction

currentVenueOrNothing :: (?context :: ControllerContext) => Maybe Venue
currentVenueOrNothing = unsafePerformIO (join <$> maybeFromContext @(Maybe Venue))

currentVenue :: (?context :: ControllerContext) => Venue
currentVenue =
    fromMaybe (error "currentVenue: no active venue in controller context") currentVenueOrNothing

currentVenueId :: (?context :: ControllerContext) => Id Venue
currentVenueId = get #id currentVenue

currentVenueMembershipOrNothing :: (?context :: ControllerContext) => Maybe VenueMembership
currentVenueMembershipOrNothing = unsafePerformIO (join <$> maybeFromContext @(Maybe VenueMembership))

currentVenueMembership :: (?context :: ControllerContext) => VenueMembership
currentVenueMembership =
    fromMaybe (error "currentVenueMembership: no active venue membership in controller context") currentVenueMembershipOrNothing

currentVenueRoleOrNothing :: (?context :: ControllerContext) => Maybe VenueRole
currentVenueRoleOrNothing = unsafePerformIO (join <$> maybeFromContext @(Maybe VenueRole))

currentVenueRole :: (?context :: ControllerContext) => VenueRole
currentVenueRole =
    fromMaybe (error "currentVenueRole: no active venue role in controller context") currentVenueRoleOrNothing

hasVenueRole :: VenueRole -> VenueRole -> Bool
hasVenueRole actualRole minimumRole = actualRole >= minimumRole

hasRole :: (?context :: ControllerContext) => VenueRole -> Bool
hasRole minimumRole =
    maybe False (`hasVenueRole` minimumRole) currentVenueRoleOrNothing

ensureCurrentVenue :: (?context :: ControllerContext) => IO ()
ensureCurrentVenue = accessDeniedUnless (isJust currentVenueMembershipOrNothing)

-- | Deny access (403) unless the current user is a manager or admin.
ensureManagerRole :: (?context :: ControllerContext) => IO ()
ensureManagerRole = accessDeniedUnless (hasRole ManagerRole')

-- | Deny access (403) unless the current user is an admin.
ensureAdminRole :: (?context :: ControllerContext) => IO ()
ensureAdminRole = accessDeniedUnless (hasRole VenueAdminRole)

-- | True when the current request came from htmx.
isHtmxRequest :: (?context :: ControllerContext) => Bool
isHtmxRequest = getHeader "HX-Request" == Just "true"

-- | Ask htmx to push a canonical URL after a fragment response.
setHtmxPushUrl :: (?context :: ControllerContext) => Text -> IO ()
setHtmxPushUrl url = setHeader ("HX-Push-Url", cs url)

-- | Parse a HH:MM text value into a TimeOfDay.
parseTimeParam :: Text -> Maybe TimeOfDay
parseTimeParam value = parseTimeM True defaultTimeLocale "%H:%M" (cs value)

-- | True when a TimeOfDay falls on a 15-minute boundary.
isQuarterHourTime :: TimeOfDay -> Bool
isQuarterHourTime tod = todMin tod `mod` 15 == 0 && todSec tod == 0

-- | True when minutes are non-negative and divisible by 15.
isQuarterHourMinutes :: Int -> Bool
isQuarterHourMinutes mins = mins >= 0 && mins `mod` 15 == 0

-- | Compute shift duration in minutes (end - start).
shiftDurationMinutes :: TimeOfDay -> TimeOfDay -> Int
shiftDurationMinutes start end =
    normalizeShiftMinuteOfDay end - normalizeShiftMinuteOfDay start

timeOfDayToMinutes :: TimeOfDay -> Int
timeOfDayToMinutes tod = todHour tod * 60 + todMin tod

-- | Normalize shift-related times onto a linear timeline where 00:00-05:45
-- are treated as next-day continuation of the same working window.
normalizeShiftMinuteOfDay :: TimeOfDay -> Int
normalizeShiftMinuteOfDay tod =
    let minuteOfDay = timeOfDayToMinutes tod
    in if minuteOfDay < 360 then minuteOfDay + 1440 else minuteOfDay

-- | True when the worked-on date is within the staff edit window (inclusive).
-- The window is measured in days from today backwards.
isWithinEditWindow :: Day -> Day -> Int -> Bool
isWithinEditWindow today workedOn windowDays =
    diffDays today workedOn <= fromIntegral windowDays

-- | Guard that denies staff access to entries outside the edit window.
-- Manager/admin roles bypass the restriction entirely.
ensureEditWindowOrManager :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Day -> IO ()
ensureEditWindowOrManager workedOn =
    unless (hasRole ManagerRole') do
        config <- fetchVenueConfig
        today <- utctDay <$> getCurrentTime
        accessDeniedUnless (isWithinEditWindow today workedOn config.staffTimesheetEditWindowDays)

-- | True when leave date range is valid.
-- Start date is first unavailable date, end date is first available date.
isLeaveDateRangeValid :: Day -> Day -> Bool
isLeaveDateRangeValid startDate endDate = endDate > startDate

-- | Returns all week offsets overlapped by an inclusive date range.
affectedWeekOffsetsForDateRange :: Day -> Day -> Day -> [Int]
affectedWeekOffsetsForDateRange epoch startDate endDate
    | not (isLeaveDateRangeValid startDate endDate) = []
    | otherwise = [startOffset .. endOffset]
    where
        toWeekOffset day = fromInteger (diffDays day epoch `div` 7)
        startOffset = toWeekOffset startDate
        leaveLastDate = addDays (-1) endDate
        endOffset = toWeekOffset leaveLastDate

-- | Touch affected roster weeks so roster pages auto-refresh and recompute conflicts.
triggerRosterConflictRecomputeForLeave :: (?context :: ControllerContext, ?modelContext :: ModelContext) => LeaveRequest -> IO ()
triggerRosterConflictRecomputeForLeave leaveRequest = do
    venueConfig <- fetchVenueConfig
    let affectedOffsets =
            affectedWeekOffsetsForDateRange
                venueConfig.weekOffsetEpoch
                leaveRequest.startDate
                leaveRequest.endDate

    unless (null affectedOffsets) do
        now <- getCurrentTime
        affectedWeeks <- query @RosterWeek
            |> filterWhereIn (#weekOffset, affectedOffsets)
            |> fetch

        forM_ affectedWeeks \rosterWeek ->
            rosterWeek
                |> set #updatedAt now
                |> updateRecordDiscardResult

fetchCurrentUserStaff :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO (Maybe Staff)
fetchCurrentUserStaff =
    query @Staff
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> filterWhere (#userId, Just (coerce (get #id currentUser)))
        |> fetchOneOrNothing

staffInCurrentVenueOrNothing :: (?context :: ControllerContext, ?modelContext :: ModelContext) => UUID -> IO (Maybe Staff)
staffInCurrentVenueOrNothing staffId =
    query @Staff
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> filterWhere (#id, Id staffId)
        |> fetchOneOrNothing

ensureOptionalStaffInCurrentVenue :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Maybe UUID -> IO ()
ensureOptionalStaffInCurrentVenue maybeStaffId =
    forM_ maybeStaffId \staffId -> do
        maybeStaff <- staffInCurrentVenueOrNothing staffId
        accessDeniedUnless (isJust maybeStaff)

ensureRecordInCurrentVenue :: (?context :: ControllerContext) => UUID -> IO ()
ensureRecordInCurrentVenue venueId =
    accessDeniedUnless (venueId == unpackId currentVenueId)

selectCurrentVenueMembership :: Maybe (Id Venue) -> [VenueMembership] -> Maybe VenueMembership
selectCurrentVenueMembership sessionVenueId memberships =
    let orderedMemberships = sortOn (.createdAt) memberships
     in case sessionVenueId >>= \venueId -> find (\membership -> membership.venueId == coerce venueId) orderedMemberships of
            Just membership -> Just membership
            Nothing         -> listToMaybe orderedMemberships

initCurrentVenueContext :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO ()
initCurrentVenueContext = do
    putContext (Nothing :: Maybe Venue)
    putContext (Nothing :: Maybe VenueMembership)
    putContext (Nothing :: Maybe VenueRole)

    forM_ currentUserOrNothing \user -> do
        sessionVenueId <- getSession @(Id Venue) currentVenueSessionKey
        maybeVenueContext <- resolveVenueContextForUser sessionVenueId (get #id user)
        case maybeVenueContext of
            Nothing -> deleteSession currentVenueSessionKey
            Just (membership, venue, role) -> do
                putContext (Just venue)
                putContext (Just membership)
                putContext (Just role)
                setSession currentVenueSessionKey (get #id venue)

resolveVenueContextForUser :: (?modelContext :: ModelContext) => Maybe (Id Venue) -> Id User -> IO (Maybe (VenueMembership, Venue, VenueRole))
resolveVenueContextForUser sessionVenueId userId = do
    memberships <- query @VenueMembership
        |> filterWhere (#userId, unpackId userId)
        |> filterWhere (#isActive, True)
        |> orderByAsc #createdAt
        |> fetch

    let venueIds = map (Id . (.venueId)) memberships
    venues <-
        if null venueIds
            then pure []
            else query @Venue
                |> filterWhereIn (#id, venueIds)
                |> filterWhere (#status, "active")
                |> fetch

    let activeVenueIds = map (coerce . (.id)) venues
    let activeMemberships = filter (\membership -> membership.venueId `elem` activeVenueIds) memberships

    pure do
        membership <- selectCurrentVenueMembership sessionVenueId activeMemberships
        venue <- find (\candidate -> coerce (get #id candidate) == membership.venueId) venues
        role <- parseVenueRole membership.venueRole
        pure (membership, venue, role)
