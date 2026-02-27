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

data DashboardController
    = DashboardAction
    deriving (Eq, Show, Data)

data ProfilesController
    = EditProfileAction
    | UpdateProfileAction
    deriving (Eq, Show, Data)

data StaffController
    = StaffAction
    | NewStaffAction
    | ShowStaffAction { staffId :: !(Id Staff) }
    | CreateStaffAction
    | EditStaffAction { staffId :: !(Id Staff) }
    | UpdateStaffAction { staffId :: !(Id Staff) }
    | DeleteStaffAction { staffId :: !(Id Staff) }
    deriving (Eq, Show, Data)

data RosterWeeksController
    = RosterWeeksAction
    | ShowRosterWeekAction { weekOffset :: !Int }
    | CreateRosterWeekAction { weekOffset :: !Int }
    | PublishRosterWeekAction { rosterWeekId :: !(Id RosterWeek) }
    deriving (Eq, Show, Data)

-- Auth support: where to redirect unauthenticated users
instance HasNewSessionUrl User where
    newSessionUrl _ = "/NewSession"

-- Tell IHP which record type represents the logged-in user
type instance CurrentUserRecord = User
