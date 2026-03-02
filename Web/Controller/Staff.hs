module Web.Controller.Staff where

import Web.Controller.Prelude
import Web.Controller.RosterWeeks ()
import Web.View.Staff.Edit

instance Controller StaffController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted
        ensureManagerRole

    action EditStaffAction { staffId } = do
        staff <- fetch staffId
        let weekOffset = paramOrDefault @Int 0 "weekOffset"
        setModal EditView { .. }
        jumpToAction ShowRosterWeekAction { weekOffset }

    action UpdateStaffAction { staffId } = do
        staff <- fetch staffId
        let weekOffset = paramOrDefault @Int 0 "weekOffset"
        staff
            |> buildStaff
            |> ifValid \case
                Left staff -> do
                    setModal EditView { .. }
                    jumpToAction ShowRosterWeekAction { weekOffset }
                Right staff -> do
                    staff <- staff |> updateRecord
                    setSuccessMessage "Staff member updated"
                    redirectTo ShowRosterWeekAction { weekOffset }

buildStaff staff = staff
    |> fill @'["firstName", "lastName", "idealShiftsPerWeek", "isActive"]
    |> validateField #firstName nonEmpty
    |> validateField #lastName nonEmpty
