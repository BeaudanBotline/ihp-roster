module Application.Helper.View where

import Application.Helper.Controller (UserRole (..), hasRole, parseUserRole)
import Generated.Types
import IHP.ViewPrelude

-- Here you can add functions which are available in all your views

-- | True when the current user has at least manager privileges.
-- Use in views for conditional rendering of management UI.
currentUserIsManager :: (?context :: ControllerContext) => Bool
currentUserIsManager = hasRole ManagerRole

-- | True when the current user is an admin.
-- Use in views for conditional rendering of admin-only UI.
currentUserIsAdmin :: (?context :: ControllerContext) => Bool
currentUserIsAdmin = hasRole AdminRole

-- | True when a staff record is a trial placeholder (no linked user account).
isTrialStaff :: Staff -> Bool
isTrialStaff staff = isNothing staff.userId
