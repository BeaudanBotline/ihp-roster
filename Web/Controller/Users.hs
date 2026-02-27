module Web.Controller.Users where

import Web.Controller.Prelude
import Web.View.Users.New

instance Controller UsersController where
    action NewUserAction = do
        let user = newRecord @User
        render NewView { .. }

    action CreateUserAction = do
        let user = newRecord @User
        let passwordConfirmation = param @Text "passwordConfirmation"
        user
            |> fill @["email", "passwordHash"]
            |> validateField #passwordHash (isEqual passwordConfirmation |> withCustomErrorMessage "Passwords don't match")
            |> validateField #passwordHash nonEmpty
            |> validateField #email isEmail
            |> validateIsUnique #email
            >>= ifValid \case
                Left user -> render NewView { .. }
                Right user -> do
                    hashed <- hashPassword user.passwordHash
                    existingUserCount <- query @User |> fetchCount
                    let assignedRole = bootstrapRegistrationRole existingUserCount
                    user <- user
                        |> set #passwordHash hashed
                        |> set #role_ (userRoleToText assignedRole)
                        |> createRecord
                    setSuccessMessage "Account created! Please log in."
                    redirectTo NewSessionAction
