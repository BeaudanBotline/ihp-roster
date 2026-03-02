module Web.Controller.Staff where

import Web.Controller.Prelude
import Web.View.Staff.Edit

instance Controller StaffController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted
        ensureManagerRole

    action EditStaffAction { staffId } = do
        staff <- fetch staffId
        render EditView { .. }

    action UpdateStaffAction { staffId } = do
        staff <- fetch staffId
        staff
            |> buildStaff
            |> ifValid \case
                Left staff -> render EditView { .. }
                Right staff -> do
                    staff <- staff |> updateRecord
                    setSuccessMessage "Staff member updated"
                    redirectTo RosterWeeksAction

buildStaff staff = staff
    |> fill @'["firstName", "lastName", "idealShiftsPerWeek", "isActive"]
    |> validateField #firstName nonEmpty
    |> validateField #lastName nonEmpty
