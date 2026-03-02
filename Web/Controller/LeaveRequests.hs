module Web.Controller.LeaveRequests where

import Data.Coerce (coerce)
import Data.Time.Calendar (addDays)
import Web.Controller.Prelude
import Web.View.LeaveRequests.Index
import Web.View.LeaveRequests.New

instance Controller LeaveRequestsController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted

    action LeaveRequestsAction = do
        staffMembers <- query @Staff |> orderByAsc #lastName |> fetch
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
                render NewView { .. }

    action CreateLeaveRequestAction = do
        maybeStaff <- fetchCurrentUserStaff
        case maybeStaff of
            Nothing -> do
                setErrorMessage "No staff record found. Contact an administrator."
                redirectTo LeaveRequestsAction
            Just staff -> do
                let leaveRequest =
                        newRecord @LeaveRequest
                            |> set #staffId (coerce (get #id staff))
                            |> set #status (leaveRequestStatusToText LeavePending)
                            |> buildLeaveRequest

                leaveRequest
                    |> ifValid \case
                        Left leaveRequest -> render NewView { .. }
                        Right leaveRequest -> do
                            _ <- leaveRequest |> createRecord
                            setSuccessMessage "Leave request submitted"
                            redirectTo LeaveRequestsAction

    action ApproveLeaveRequestAction { leaveRequestId } = do
        ensureManagerRole
        leaveRequest <- fetch leaveRequestId
        withTransaction do
            let wasApproved = parseLeaveRequestStatus leaveRequest.status == Just LeaveApproved
            updatedLeaveRequest <-
                leaveRequest
                    |> set #status (leaveRequestStatusToText LeaveApproved)
                    |> updateRecord
            unless wasApproved do
                triggerRosterConflictRecomputeForLeave updatedLeaveRequest
        setSuccessMessage "Leave request approved"
        redirectTo LeaveRequestsAction

    action DenyLeaveRequestAction { leaveRequestId } = do
        ensureManagerRole
        leaveRequest <- fetch leaveRequestId
        withTransaction do
            let wasApproved = parseLeaveRequestStatus leaveRequest.status == Just LeaveApproved
            updatedLeaveRequest <-
                leaveRequest
                    |> set #status (leaveRequestStatusToText LeaveDenied)
                    |> updateRecord
            when wasApproved do
                triggerRosterConflictRecomputeForLeave updatedLeaveRequest
        setSuccessMessage "Leave request denied"
        redirectTo LeaveRequestsAction

    action DeleteLeaveRequestAction { leaveRequestId } = do
        leaveRequest <- fetch leaveRequestId
        ensureLeaveDeleteAllowed leaveRequest
        withTransaction do
            when (parseLeaveRequestStatus leaveRequest.status == Just LeaveApproved) do
                triggerRosterConflictRecomputeForLeave leaveRequest
            deleteRecord leaveRequest
        setSuccessMessage "Leave request deleted"
        redirectTo LeaveRequestsAction

fetchCurrentUserStaff :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO (Maybe Staff)
fetchCurrentUserStaff =
    query @Staff
        |> filterWhere (#userId, Just (coerce (get #id currentUser)))
        |> fetchOneOrNothing

fetchVisibleLeaveRequests :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO [LeaveRequest]
fetchVisibleLeaveRequests = do
    maybeStaff <- fetchCurrentUserStaff
    case maybeStaff of
        Nothing -> pure []
        Just staff ->
            query @LeaveRequest
                |> filterWhere (#staffId, coerce (get #id staff))
                |> orderByDesc #startDate
                |> fetch

ensureLeaveDeleteAllowed :: (?context :: ControllerContext, ?modelContext :: ModelContext) => LeaveRequest -> IO ()
ensureLeaveDeleteAllowed leaveRequest =
    if hasRole ManagerRole
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
