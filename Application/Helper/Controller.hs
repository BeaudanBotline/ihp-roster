module Application.Helper.Controller where

import Data.Time.Calendar (Day, addDays, diffDays)
import Data.Time.Clock (UTCTime (..), getCurrentTime)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Data.Time.LocalTime (TimeOfDay (..))
import Generated.Types
import IHP.ControllerPrelude
import Web.Routes ()
import Web.Types (ProfilesController (EditProfileAction))

-- Here you can add functions which are available in all your controllers

fetchVenueConfig :: (?modelContext :: ModelContext) => IO VenueConfig
fetchVenueConfig = query @VenueConfig |> fetchOne

data UserRole
    = StaffRole
    | ManagerRole
    | AdminRole
    deriving (Eq, Show)

data LeaveRequestStatus
    = LeavePending
    | LeaveApproved
    | LeaveDenied
    deriving (Eq, Show)

allUserRoleValues :: [Text]
allUserRoleValues = ["staff", "manager", "admin"]

allLeaveRequestStatusValues :: [Text]
allLeaveRequestStatusValues = ["pending", "approved", "denied"]

parseUserRole :: Text -> Maybe UserRole
parseUserRole "staff"   = Just StaffRole
parseUserRole "manager" = Just ManagerRole
parseUserRole "admin"   = Just AdminRole
parseUserRole _         = Nothing

parseLeaveRequestStatus :: Text -> Maybe LeaveRequestStatus
parseLeaveRequestStatus "pending"  = Just LeavePending
parseLeaveRequestStatus "approved" = Just LeaveApproved
parseLeaveRequestStatus "denied"   = Just LeaveDenied
parseLeaveRequestStatus _          = Nothing

userRoleToText :: UserRole -> Text
userRoleToText StaffRole   = "staff"
userRoleToText ManagerRole = "manager"
userRoleToText AdminRole   = "admin"

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

-- | Returns the parsed role of the current logged-in user.
currentUserRole :: (?context :: ControllerContext) => UserRole
currentUserRole = fromMaybe StaffRole (parseUserRole currentUser.userRole)

-- | True when the current user's role is at least the given minimum.
hasRole :: (?context :: ControllerContext) => UserRole -> Bool
hasRole minimumRole = roleLevel currentUserRole >= roleLevel minimumRole
    where
        roleLevel :: UserRole -> Int
        roleLevel StaffRole   = 0
        roleLevel ManagerRole = 1
        roleLevel AdminRole   = 2

-- | Deny access (403) unless the current user is a manager or admin.
ensureManagerRole :: (?context :: ControllerContext) => IO ()
ensureManagerRole = accessDeniedUnless (hasRole ManagerRole)

-- | Deny access (403) unless the current user is an admin.
ensureAdminRole :: (?context :: ControllerContext) => IO ()
ensureAdminRole = accessDeniedUnless (hasRole AdminRole)

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
    unless (hasRole ManagerRole) do
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
triggerRosterConflictRecomputeForLeave :: (?modelContext :: ModelContext) => LeaveRequest -> IO ()
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
