module Web.Controller.Users where

import Control.Monad (void)
import qualified Data.Aeson as Aeson
import Web.Controller.Prelude
import Web.View.Users.New

instance Controller UsersController where
    action NewUserAction = do
        let invitationId = paramOrNothing @(Id VenueInvitation) "invitationId"
        case invitationId of
            Nothing -> do
                setTitle "Request Access"
                render InviteOnlyView
            Just invitationId -> do
                now <- getCurrentTime
                invitationOrNothing <- fetchInvitation invitationId
                case invitationOrNothing of
                    Just invitation | invitationIsActive now invitation -> do
                        let user = newRecord @User |> set #email invitation.email
                        setTitle "Accept Invitation"
                        render InvitationSignupView { .. }
                    _ -> do
                        setErrorMessage "That invitation is no longer valid. Contact support for a new bootstrap invite."
                        setTitle "Request Access"
                        render InviteOnlyView

    action CreateUserAction = do
        let invitationId = paramOrNothing @(Id VenueInvitation) "invitationId"
        case invitationId of
            Nothing -> do
                setErrorMessage "Account creation is invitation-only. Contact support for a bootstrap invite."
                setTitle "Request Access"
                render InviteOnlyView
            Just invitationId -> do
                now <- getCurrentTime
                invitationOrNothing <- fetchInvitation invitationId
                case invitationOrNothing of
                    Just invitation | invitationIsActive now invitation -> do
                        let passwordConfirmation = param @Text "passwordConfirmation"
                        let user = newRecord @User |> set #email invitation.email
                        user
                            |> fill @'["passwordHash"]
                            |> validateField #passwordHash (isEqual passwordConfirmation |> withCustomErrorMessage "Passwords don't match")
                            |> validateField #passwordHash nonEmpty
                            |> validateField #email isEmail
                            |> validateIsUnique #email
                            >>= ifValid \case
                                Left user -> do
                                    setTitle "Accept Invitation"
                                    render InvitationSignupView { .. }
                                Right user -> do
                                    hashed <- hashPassword user.passwordHash
                                    withTransaction do
                                        user <- user
                                            |> set #passwordHash hashed
                                            |> createRecord
                                        membership <- newRecord @VenueMembership
                                            |> set #venueId invitation.venueId
                                            |> set #userId (unpackId (get #id user))
                                            |> set #venueRole invitation.inviteRole
                                            |> set #isActive True
                                            |> createRecord
                                        _ <- invitation
                                            |> set #status "accepted"
                                            |> set #acceptedByUserId (Just (unpackId (get #id user)))
                                            |> set #acceptedAt (Just now)
                                            |> updateRecord
                                        void $ recordAuditEvent
                                            invitation.venueId
                                            (unpackId (get #id user))
                                            "venue_role_assigned"
                                            "venue_memberships"
                                            (unpackId (get #id membership))
                                            (Aeson.object
                                                [ "email" Aeson..= user.email
                                                , "assignedRole" Aeson..= membership.venueRole
                                                , "invitationId" Aeson..= unpackId (get #id invitation)
                                                ]
                                            )
                                            requestAuditSourceChannel
                                    setSuccessMessage "Account created from invitation. Please sign in."
                                    redirectTo NewSessionAction
                    _ -> do
                        setErrorMessage "That invitation is no longer valid. Contact support for a new bootstrap invite."
                        setTitle "Request Access"
                        render InviteOnlyView

fetchInvitation :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Id VenueInvitation -> IO (Maybe VenueInvitation)
fetchInvitation invitationId =
    query @VenueInvitation
        |> filterWhere (#id, invitationId)
        |> fetchOneOrNothing

invitationIsActive :: UTCTime -> VenueInvitation -> Bool
invitationIsActive now invitation =
    invitation.status == "pending"
        && isNothing invitation.acceptedAt
        && maybe True (> now) invitation.expiresAt
