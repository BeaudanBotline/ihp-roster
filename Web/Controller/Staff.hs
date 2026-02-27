module Web.Controller.Staff where

import Web.Controller.Prelude
import Web.View.Staff.Edit
import Web.View.Staff.Index
import Web.View.Staff.New
import Web.View.Staff.Show

instance Controller StaffController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted
        ensureManagerRole

    action StaffAction = do
        let staffFilter = paramOrDefault @Text "filter" "all"
        let baseQuery = query @Staff |> orderByAsc #lastName |> orderByAsc #firstName
        staffMembers <- case staffFilter of
            "trial"  -> baseQuery |> filterWhere (#userId, Nothing :: Maybe UUID) |> fetch
            "linked" -> baseQuery |> filterWhereNot (#userId, Nothing :: Maybe UUID) |> fetch
            _        -> baseQuery |> fetch
        render IndexView { .. }

    action NewStaffAction = do
        let staff = newRecord @Staff
        render NewView { .. }

    action ShowStaffAction { staffId } = do
        staff <- fetch staffId
        render ShowView { .. }

    action CreateStaffAction = do
        let staff = newRecord @Staff
        staff
            |> buildStaff
            |> ifValid \case
                Left staff -> render NewView { .. }
                Right staff -> do
                    staff <- staff |> createRecord
                    setSuccessMessage "Staff member created"
                    redirectTo StaffAction

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
                    redirectTo StaffAction

    action DeleteStaffAction { staffId } = do
        staff <- fetch staffId
        deleteRecord staff
        setSuccessMessage "Staff member deleted"
        redirectTo StaffAction

buildStaff staff = staff
    |> fill @'["firstName", "lastName", "isActive"]
    |> validateField #firstName nonEmpty
    |> validateField #lastName nonEmpty
