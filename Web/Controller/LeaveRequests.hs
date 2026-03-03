module Web.Controller.LeaveRequests where

import Application.Helper.View (ToastOverlayConfig (..),
                                ToastOverlayPosition (..),
                                renderToastOverlayHostOob)
import Control.Monad (void)
import qualified Data.Aeson as Aeson
import Data.Coerce (coerce)
import Data.Time.Calendar (addDays)
import Web.Controller.Prelude
import Web.View.LeaveRequests.Index
import Web.View.LeaveRequests.New

instance Controller LeaveRequestsController where
    beforeAction = do
        ensureIsUser
        ensureCurrentVenue
        ensureProfileCompleted

    action LeaveRequestsAction = do
        staffMembers <- query @Staff |> filterWhere (#venueId, unpackId currentVenueId) |> orderByAsc #lastName |> fetch
        leaveRequests <- fetchVisibleLeaveRequests
        render IndexView { .. }

    action NewLeaveRequestAction = do
        maybeStaff <- fetchCurrentUserStaff
        case maybeStaff of
            Nothing -> do
                setErrorMessage "No staff record found. Contact an administrator."
                redirectTo LeaveRequestsAction
            Just _ -> do
                today <- utctDay <$> getCurrentTime
                let leaveRequest =
                        newRecord @LeaveRequest
                            |> set #startDate today
                            |> set #endDate (addDays 1 today)
                if isHtmxRequest
                    then respondHtml (renderNewLeaveRequestDialog leaveRequest)
                    else render NewView { .. }

    action CreateLeaveRequestAction = do
        maybeStaff <- fetchCurrentUserStaff
        case maybeStaff of
            Nothing -> do
                setErrorMessage "No staff record found. Contact an administrator."
                redirectTo LeaveRequestsAction
            Just staff -> do
                let leaveRequest =
                        newRecord @LeaveRequest
                            |> set #venueId (unpackId currentVenueId)
                            |> set #staffId (coerce (get #id staff))
                            |> set #status (leaveRequestStatusToText LeavePending)
                            |> buildLeaveRequest

                leaveRequest
                    |> ifValid \case
                        Left leaveRequest ->
                            if isHtmxRequest
                                then respondHtml (renderNewLeaveRequestDialog leaveRequest)
                                else render NewView { .. }
                        Right leaveRequest -> do
                            _ <- leaveRequest |> createRecord
                            if isHtmxRequest
                                then respondWithLeaveRequestsContent
                                else do
                                    setSuccessMessage "Leave request submitted"
                                    redirectTo LeaveRequestsAction

    action ApproveLeaveRequestAction { leaveRequestId } = do
        ensureManagerRole
        leaveRequest <- fetch leaveRequestId
        ensureRecordInCurrentVenue leaveRequest.venueId
        withTransaction do
            let wasApproved = parseLeaveRequestStatus leaveRequest.status == Just LeaveApproved
            updatedLeaveRequest <-
                leaveRequest
                    |> set #status (leaveRequestStatusToText LeaveApproved)
                    |> updateRecord
            unless wasApproved do
                triggerRosterConflictRecomputeForLeave updatedLeaveRequest
            void $ recordCurrentUserAuditEvent
                "leave_approved"
                "leave_requests"
                (unpackId (get #id leaveRequest))
                (Aeson.object
                    [ "staffId" Aeson..= leaveRequest.staffId
                    , "startDate" Aeson..= leaveRequest.startDate
                    , "endDate" Aeson..= leaveRequest.endDate
                    , "previousStatus" Aeson..= leaveRequest.status
                    , "newStatus" Aeson..= updatedLeaveRequest.status
                    ]
                )
        setSuccessMessage "Leave request approved"
        redirectTo LeaveRequestsAction

    action DenyLeaveRequestAction { leaveRequestId } = do
        ensureManagerRole
        leaveRequest <- fetch leaveRequestId
        ensureRecordInCurrentVenue leaveRequest.venueId
        withTransaction do
            let wasApproved = parseLeaveRequestStatus leaveRequest.status == Just LeaveApproved
            updatedLeaveRequest <-
                leaveRequest
                    |> set #status (leaveRequestStatusToText LeaveDenied)
                    |> updateRecord
            when wasApproved do
                triggerRosterConflictRecomputeForLeave updatedLeaveRequest
            void $ recordCurrentUserAuditEvent
                "leave_denied"
                "leave_requests"
                (unpackId (get #id leaveRequest))
                (Aeson.object
                    [ "staffId" Aeson..= leaveRequest.staffId
                    , "startDate" Aeson..= leaveRequest.startDate
                    , "endDate" Aeson..= leaveRequest.endDate
                    , "previousStatus" Aeson..= leaveRequest.status
                    , "newStatus" Aeson..= updatedLeaveRequest.status
                    ]
                )
        setSuccessMessage "Leave request denied"
        redirectTo LeaveRequestsAction

    action DeleteLeaveRequestAction { leaveRequestId } = do
        leaveRequest <- fetch leaveRequestId
        ensureRecordInCurrentVenue leaveRequest.venueId
        ensureLeaveDeleteAllowed leaveRequest
        withTransaction do
            when (parseLeaveRequestStatus leaveRequest.status == Just LeaveApproved) do
                triggerRosterConflictRecomputeForLeave leaveRequest
            void $ recordCurrentUserAuditEvent
                "leave_deleted"
                "leave_requests"
                (unpackId (get #id leaveRequest))
                (Aeson.object
                    [ "staffId" Aeson..= leaveRequest.staffId
                    , "startDate" Aeson..= leaveRequest.startDate
                    , "endDate" Aeson..= leaveRequest.endDate
                    , "deletedStatus" Aeson..= leaveRequest.status
                    ]
                )
            deleteRecord leaveRequest
        setSuccessMessage "Leave request deleted"
        redirectTo LeaveRequestsAction

fetchVisibleLeaveRequests :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO [LeaveRequest]
fetchVisibleLeaveRequests = do
    if hasRole ManagerRole'
        then
            query @LeaveRequest
                |> filterWhere (#venueId, unpackId currentVenueId)
                |> orderByDesc #startDate
                |> fetch
        else do
            maybeStaff <- fetchCurrentUserStaff
            case maybeStaff of
                Nothing -> pure []
                Just staff ->
                    query @LeaveRequest
                        |> filterWhere (#venueId, unpackId currentVenueId)
                        |> filterWhere (#staffId, coerce (get #id staff))
                        |> orderByDesc #startDate
                        |> fetch

respondWithLeaveRequestsContent :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO ()
respondWithLeaveRequestsContent = do
    staffMembers <- query @Staff |> filterWhere (#venueId, unpackId currentVenueId) |> orderByAsc #lastName |> fetch
    leaveRequests <- fetchVisibleLeaveRequests
    respondHtml $
        mconcat
            [ renderLeaveRequestsContentFragmentOob leaveRequests staffMembers
            , renderToastOverlayHostOob ToastBottomCenter
                [ ToastOverlayConfig
                    { toastOverlayTitle = Just "Success"
                    , toastOverlayMessage = "Leave request submitted"
                    , toastOverlayClass = "app-toast-success"
                    , toastOverlayAutoHideMs = 3200
                    }
                ]
            ]

ensureLeaveDeleteAllowed :: (?context :: ControllerContext, ?modelContext :: ModelContext) => LeaveRequest -> IO ()
ensureLeaveDeleteAllowed leaveRequest =
    if hasRole ManagerRole'
        then pure ()
        else do
            maybeStaff <- fetchCurrentUserStaff
            let canDeleteOwn = maybe False (\staff -> coerce (get #id staff) == leaveRequest.staffId) maybeStaff
            accessDeniedUnless canDeleteOwn

buildLeaveRequest :: (?context :: ControllerContext) => LeaveRequest -> LeaveRequest
buildLeaveRequest leaveRequest =
    leaveRequest
        |> fill @'["startDate", "endDate", "notes"]
        |> validateField #endDate (validateEndDate leaveRequest.startDate)
    where
        validateEndDate startDate endDate =
            if isLeaveDateRangeValid startDate endDate
                then Success
                else Failure "Available again must be at least one day after unavailable from"
