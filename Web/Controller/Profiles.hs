module Web.Controller.Profiles where

import Web.Controller.Prelude
import Web.View.Profiles.Edit

instance Controller ProfilesController where
    beforeAction = do
        ensureIsUser
        ensureCurrentVenue

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
                    let wasProfileCompleted = currentUser.isProfileCompleted
                    currentUser
                        |> set #isProfileCompleted isProfileCompleted
                        |> updateRecord
                    setSuccessMessage "Profile updated"
                    if not wasProfileCompleted && isProfileCompleted
                        then redirectTo RosterWeeksAction
                        else redirectTo EditProfileAction

fetchCurrentUserStaffOrNew :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO Staff
fetchCurrentUserStaffOrNew = do
    maybeStaff <- fetchCurrentUserStaff
    pure case maybeStaff of
        Just staff -> staff
        Nothing ->
            newRecord @Staff
                |> set #venueId (unpackId currentVenueId)
                |> set #userId (Just (unpackId (get #id currentUser)))

upsertCurrentUserStaff :: (?modelContext :: ModelContext, ?context :: ControllerContext) => Staff -> IO Staff
upsertCurrentUserStaff staff = do
    existingStaff <- fetchCurrentUserStaff

    case existingStaff of
        Just existing ->
            existing
                |> set #firstName staff.firstName
                |> set #lastName staff.lastName
                |> updateRecord
        Nothing ->
            staff
                |> set #venueId (unpackId currentVenueId)
                |> set #userId (Just (unpackId (get #id currentUser)))
                |> createRecord
