module Web.Controller.LeaveRequests where

import Application.Helper.View (ToastOverlayConfig (..),
                                ToastOverlayPosition (..),
                                renderToastOverlayHostOob)
import Control.Monad (void)
import qualified Data.Aeson as Aeson
import Data.Coerce (coerce)
import Data.Time.Calendar (addDays)
import Web.Controller.Prelude
import Web.Controller.RosterWeeks (broadcastRosterWeekInvalidation,
                                   buildRosterContentFragmentRef,
                                   buildRosterStaffPanelFragmentRef)
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
                            |> set #status (leaveRequestStatusToEnum LeavePending)
                            |> buildLeaveRequest

                leaveRequest
                    |> ifValid \case
                        Left leaveRequest ->
                            if isHtmxRequest
                                then respondHtml (renderNewLeaveRequestDialog leaveRequest)
                                else render NewView { .. }
                        Right leaveRequest -> do
                            _ <- withTransaction do
                                createdLeaveRequest <- leaveRequest |> createRecord
                                void $
                                    recordCurrentUserLeaveRequestEvent
                                        createdLeaveRequest
                                        (unsafeEnumFromText @LeaveRequestEventTypeEnum "created")
                                        Nothing
                                        (Just createdLeaveRequest.status)
                                        Aeson.Null
                                pure createdLeaveRequest
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
                    |> set #status (leaveRequestStatusToEnum LeaveApproved)
                    |> updateRecord
            void $
                recordCurrentUserLeaveRequestEvent
                    updatedLeaveRequest
                    (unsafeEnumFromText @LeaveRequestEventTypeEnum "approved")
                    (Just leaveRequest.status)
                    (Just updatedLeaveRequest.status)
                    Aeson.Null
            unless wasApproved do
                invalidateAffectedRosterWeeksForLeave updatedLeaveRequest
            void $ recordCurrentUserAuditEvent
                "leave_approved"
                "leave_requests"
                (unpackId (get #id leaveRequest))
                (Aeson.object
                    [ "staffId" Aeson..= leaveRequest.staffId
                    , "startDate" Aeson..= leaveRequest.startDate
                    , "endDate" Aeson..= leaveRequest.endDate
                    , "previousStatus" Aeson..= inputValue leaveRequest.status
                    , "newStatus" Aeson..= inputValue updatedLeaveRequest.status
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
                    |> set #status (leaveRequestStatusToEnum LeaveDenied)
                    |> updateRecord
            void $
                recordCurrentUserLeaveRequestEvent
                    updatedLeaveRequest
                    (unsafeEnumFromText @LeaveRequestEventTypeEnum "denied")
                    (Just leaveRequest.status)
                    (Just updatedLeaveRequest.status)
                    Aeson.Null
            when wasApproved do
                invalidateAffectedRosterWeeksForLeave updatedLeaveRequest
            void $ recordCurrentUserAuditEvent
                "leave_denied"
                "leave_requests"
                (unpackId (get #id leaveRequest))
                (Aeson.object
                    [ "staffId" Aeson..= leaveRequest.staffId
                    , "startDate" Aeson..= leaveRequest.startDate
                    , "endDate" Aeson..= leaveRequest.endDate
                    , "previousStatus" Aeson..= inputValue leaveRequest.status
                    , "newStatus" Aeson..= inputValue updatedLeaveRequest.status
                    ]
                )
        setSuccessMessage "Leave request denied"
        redirectTo LeaveRequestsAction

    action DeleteLeaveRequestAction { leaveRequestId } = do
        leaveRequest <- fetch leaveRequestId
        ensureRecordInCurrentVenue leaveRequest.venueId
        ensureLeaveDeleteAllowed leaveRequest
        unless (leaveRequestCanBeDeleted leaveRequest) do
            setErrorMessage "Reviewed leave requests cannot be deleted."
            redirectTo LeaveRequestsAction
        withTransaction do
            void $
                recordCurrentUserLeaveRequestEvent
                    leaveRequest
                    (unsafeEnumFromText @LeaveRequestEventTypeEnum "deleted")
                    (Just leaveRequest.status)
                    Nothing
                    Aeson.Null
            void $ recordCurrentUserAuditEvent
                "leave_deleted"
                "leave_requests"
                (unpackId (get #id leaveRequest))
                (Aeson.object
                    [ "staffId" Aeson..= leaveRequest.staffId
                    , "startDate" Aeson..= leaveRequest.startDate
                    , "endDate" Aeson..= leaveRequest.endDate
                    , "deletedStatus" Aeson..= inputValue leaveRequest.status
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

invalidateAffectedRosterWeeksForLeave :: (?context :: ControllerContext, ?modelContext :: ModelContext) => LeaveRequest -> IO ()
invalidateAffectedRosterWeeksForLeave leaveRequest = do
    venueConfig <- fetchVenueConfig
    let affectedOffsets =
            affectedWeekOffsetsForDateRange
                venueConfig.weekOffsetEpoch
                leaveRequest.startDate
                leaveRequest.endDate

    forM_ affectedOffsets \weekOffset ->
        broadcastRosterWeekInvalidation
            weekOffset
            [ buildRosterContentFragmentRef weekOffset
            , buildRosterStaffPanelFragmentRef weekOffset
            ]
