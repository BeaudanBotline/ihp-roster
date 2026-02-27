module Application.Helper.Controller where

import Generated.Types
import IHP.ControllerPrelude

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
