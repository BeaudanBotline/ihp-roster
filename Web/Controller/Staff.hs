module Web.Controller.Staff where

import Web.Controller.Prelude
import Web.Controller.RosterWeeks (respondWithRosterContentOob)
import Web.View.Staff.Edit

instance Controller StaffController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted
        ensureManagerRole

    action EditStaffAction { staffId } = do
        staff <- fetch staffId
        let weekOffset = paramOrDefault @Int 0 "weekOffset"
        if isHtmxRequest
            then respondHtml (renderStaffEditModalFragment staff weekOffset)
            else render EditView { .. }

    action UpdateStaffAction { staffId } = do
        staff <- fetch staffId
        let weekOffset = paramOrDefault @Int 0 "weekOffset"
        staff
            |> buildStaff
            |> ifValid \case
                Left staff -> do
                    if isHtmxRequest
                        then respondHtml (renderStaffEditModalFragment staff weekOffset)
                        else render EditView { .. }
                Right staff -> do
                    staff <- staff |> updateRecord
                    if isHtmxRequest
                        then respondWithRosterContentOob weekOffset
                        else do
                            setSuccessMessage "Staff member updated"
                            redirectTo ShowRosterWeekAction { weekOffset }

buildStaff staff = staff
    |> fill @'["firstName", "lastName", "idealShiftsPerWeek", "isActive"]
    |> validateField #firstName nonEmpty
    |> validateField #lastName nonEmpty
