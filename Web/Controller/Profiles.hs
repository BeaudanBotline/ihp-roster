module Web.Controller.Profiles where

import Web.Controller.Prelude
import Web.View.Profiles.Edit

instance Controller ProfilesController where
    beforeAction = ensureIsUser

    action EditProfileAction = do
        staff <- fetchCurrentUserStaffOrNew
        render EditView { .. }

    action UpdateProfileAction = do
        staff <- fetchCurrentUserStaffOrNew
        staff
            |> fill @'["firstName", "lastName"]
            |> validateField #firstName nonEmpty
            |> validateField #lastName nonEmpty
            |> ifValid \case
                Left staff -> render EditView { .. }
                Right staff -> do
                    staff <- upsertCurrentUserStaff staff
                    let isProfileCompleted = requiredProfileFieldsCompleted staff.firstName staff.lastName
                    currentUser
                        |> set #isProfileCompleted isProfileCompleted
                        |> updateRecord
                    setSuccessMessage "Profile updated"
                    redirectTo DashboardAction

fetchCurrentUserStaffOrNew :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO Staff
fetchCurrentUserStaffOrNew = do
    maybeStaff <- query @Staff
        |> filterWhere (#userId, Just (unpackId currentUser.id))
        |> fetchOneOrNothing
    pure case maybeStaff of
        Just staff -> staff
        Nothing ->
            newRecord @Staff
                |> set #userId (Just (unpackId currentUser.id))

upsertCurrentUserStaff :: (?modelContext :: ModelContext, ?context :: ControllerContext) => Staff -> IO Staff
upsertCurrentUserStaff staff = do
    existingStaff <- query @Staff
        |> filterWhere (#userId, Just (unpackId currentUser.id))
        |> fetchOneOrNothing

    case existingStaff of
        Just existing ->
            existing
                |> set #firstName staff.firstName
                |> set #lastName staff.lastName
                |> updateRecord
        Nothing ->
            staff
                |> set #userId (Just (unpackId currentUser.id))
                |> createRecord
