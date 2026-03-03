module Web.Types where

import Generated.Types
import IHP.LoginSupport.Types
import IHP.ModelSupport
import IHP.Prelude

data WebApplication = WebApplication deriving (Eq, Show)


data StaticController = WelcomeAction deriving (Eq, Show, Data)

data SessionsController
    = NewSessionAction
    | CreateSessionAction
    | DeleteSessionAction
    deriving (Eq, Show, Data)

data UsersController
    = NewUserAction
    | CreateUserAction
    deriving (Eq, Show, Data)

data ProfilesController
    = EditProfileAction
    | UpdateProfileAction
    deriving (Eq, Show, Data)

data TimesheetsController
    = TimesheetsAction
    | ShowTimesheetWeekAction { weekOffset :: !Int }
    | NewTimesheetEntryAction
    | CreateTimesheetEntryAction
    | EditTimesheetEntryAction { timesheetEntryId :: !(Id TimesheetEntry) }
    | UpdateTimesheetEntryAction { timesheetEntryId :: !(Id TimesheetEntry) }
    | DeleteTimesheetEntryAction { timesheetEntryId :: !(Id TimesheetEntry) }
    | ApproveTimesheetEntryAction { timesheetEntryId :: !(Id TimesheetEntry) }
    | UnapproveTimesheetEntryAction { timesheetEntryId :: !(Id TimesheetEntry) }
    deriving (Eq, Show, Data)

data LeaveRequestsController
    = LeaveRequestsAction
    | NewLeaveRequestAction
    | CreateLeaveRequestAction
    | ApproveLeaveRequestAction { leaveRequestId :: !(Id LeaveRequest) }
    | DenyLeaveRequestAction { leaveRequestId :: !(Id LeaveRequest) }
    | DeleteLeaveRequestAction { leaveRequestId :: !(Id LeaveRequest) }
    deriving (Eq, Show, Data)

data ExportsController
    = ExportJobsAction
    | CreateExportJobAction
    | DownloadExportJobAction { exportJobId :: !(Id ExportJob) }
    deriving (Eq, Show, Data)

data AdminController
    = AdminAction
    | CreatePayConfigSnapshotAction
    deriving (Eq, Show, Data)

data StaffController
    = EditStaffAction { staffId :: !(Id Staff) }
    | UpdateStaffAction { staffId :: !(Id Staff) }
    deriving (Eq, Show, Data)

data RosterWeeksController
    = RosterWeeksAction
    | ShowRosterWeekAction { weekOffset :: !Int }
    | CreateRosterWeekAction { weekOffset :: !Int }
    | CopyRosterWeekAction { sourceWeekOffset :: !Int, targetWeekOffset :: !Int }
    | PublishRosterWeekAction { rosterWeekId :: !(Id RosterWeek) }
    | AddRosterRowAction { rosterDayId :: !(Id RosterDay) }
    | RemoveRosterRowAction { rosterDayId :: !(Id RosterDay) }
    | UpdateRosterSlotAction { rosterSlotId :: !(Id RosterSlot) }
    deriving (Eq, Show, Data)

-- Auth support: where to redirect unauthenticated users
instance HasNewSessionUrl User where
    newSessionUrl _ = "/NewSession"

-- Tell IHP which record type represents the logged-in user
type instance CurrentUserRecord = User
