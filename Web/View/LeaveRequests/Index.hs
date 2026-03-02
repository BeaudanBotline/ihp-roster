module Web.View.LeaveRequests.Index where

import Application.Helper.Controller (LeaveRequestStatus (..),
                                      parseLeaveRequestStatus)
import Data.Coerce (coerce)
import Web.View.Prelude

data IndexView = IndexView
    { leaveRequests :: [LeaveRequest]
    , staffMembers  :: [Staff]
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h1>Leave Requests</h1>
            <a href={NewLeaveRequestAction} class="btn btn-primary">New Request</a>
        </div>

        {if null leaveRequests
            then renderEmptyState
            else renderLeaveRequestsTable leaveRequests staffMembers
        }
    |]

renderEmptyState :: Html
renderEmptyState = [hsx|
    <div class="app-panel app-form-width">
        <div class="app-panel-body">
            <p class="app-muted mb-0">No leave requests yet.</p>
        </div>
    </div>
|]

renderLeaveRequestsTable :: (?context :: ControllerContext) => [LeaveRequest] -> [Staff] -> Html
renderLeaveRequestsTable leaveRequests staffMembers = [hsx|
    <div class="table-responsive">
        <table class="table table-striped align-middle">
            <thead>
                <tr>
                    <th>Start</th>
                    <th>End</th>
                    <th>Staff</th>
                    <th>Status</th>
                    <th>Notes</th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                {forEach leaveRequests (renderLeaveRequestRow staffMembers)}
            </tbody>
        </table>
    </div>
|]

renderLeaveRequestRow :: (?context :: ControllerContext) => [Staff] -> LeaveRequest -> Html
renderLeaveRequestRow staffMembers leaveRequest = [hsx|
    <tr>
        <td>{leaveRequest.startDate}</td>
        <td>{leaveRequest.endDate}</td>
        <td>{resolveStaffName leaveRequest.staffId staffMembers}</td>
        <td>{renderStatusBadge leaveRequest.status}</td>
        <td>{fromMaybe "-" leaveRequest.notes}</td>
        <td class="text-end">{renderReviewActions leaveRequest}</td>
    </tr>
|]

resolveStaffName :: UUID -> [Staff] -> Text
resolveStaffName staffUuid staffMembers =
    case find (\staff -> coerce (get #id staff) == staffUuid) staffMembers of
        Just staff -> staff.firstName <> " " <> staff.lastName
        Nothing    -> "Unknown" :: Text

renderStatusBadge :: Text -> Html
renderStatusBadge status =
    case parseLeaveRequestStatus status of
        Just LeaveApproved -> [hsx|<span class="badge bg-success">Approved</span>|]
        Just LeaveDenied -> [hsx|<span class="badge bg-danger">Denied</span>|]
        _ -> [hsx|<span class="badge bg-warning text-dark">Pending</span>|]

renderReviewActions :: (?context :: ControllerContext) => LeaveRequest -> Html
renderReviewActions leaveRequest
    | not currentUserIsManager = mempty
    | otherwise = case parseLeaveRequestStatus leaveRequest.status of
        Just LeaveApproved -> [hsx|
            <a href={DenyLeaveRequestAction leaveRequest.id} class="btn btn-sm btn-outline-danger js-delete js-delete-no-confirm">Deny</a>
        |]
        Just LeaveDenied -> [hsx|
            <a href={ApproveLeaveRequestAction leaveRequest.id} class="btn btn-sm btn-outline-success js-delete js-delete-no-confirm">Approve</a>
        |]
        _ -> [hsx|
            <a href={ApproveLeaveRequestAction leaveRequest.id} class="btn btn-sm btn-outline-success me-1 js-delete js-delete-no-confirm">Approve</a>
            <a href={DenyLeaveRequestAction leaveRequest.id} class="btn btn-sm btn-outline-danger js-delete js-delete-no-confirm">Deny</a>
        |]
