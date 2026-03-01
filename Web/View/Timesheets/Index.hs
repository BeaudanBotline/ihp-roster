module Web.View.Timesheets.Index where

import Application.Helper.Controller (isWithinEditWindow)
import Web.View.Prelude

data IndexView = IndexView
    { entries        :: [TimesheetEntry]
    , staffMembers   :: [Staff]
    , today          :: Day
    , editWindowDays :: Int
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h1>Timesheets</h1>
            <div class="d-flex gap-2">
                <a href={LeaveRequestsAction} class="btn btn-outline-secondary">Leave Requests</a>
                <a href={NewTimesheetEntryAction} class="btn btn-primary">New Entry</a>
            </div>
        </div>

        {if null entries
            then renderEmptyState
            else renderEntriesTable entries staffMembers today editWindowDays
        }
    |]

renderEmptyState :: Html
renderEmptyState = [hsx|
    <div class="app-panel app-form-width">
        <div class="app-panel-body">
            <p class="app-muted mb-0">No timesheet entries yet.</p>
        </div>
    </div>
|]

renderEntriesTable :: (?context :: ControllerContext) => [TimesheetEntry] -> [Staff] -> Day -> Int -> Html
renderEntriesTable entries staffMembers today editWindowDays = [hsx|
    <div class="table-responsive">
        <table class="table table-striped align-middle">
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Staff</th>
                    <th>Start</th>
                    <th>End</th>
                    <th>Break</th>
                    <th>Duration</th>
                    <th>Status</th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                {forEach entries (renderEntryRow staffMembers today editWindowDays)}
            </tbody>
        </table>
    </div>
|]

renderEntryRow :: (?context :: ControllerContext) => [Staff] -> Day -> Int -> TimesheetEntry -> Html
renderEntryRow staffMembers today editWindowDays entry = [hsx|
    <tr>
        <td>{entry.workedOn}</td>
        <td>{staffName}</td>
        <td>{storageTimeToDisplayLabel (timeOfDayToStorageValue entry.startTime)}</td>
        <td>{storageTimeToDisplayLabel (timeOfDayToStorageValue entry.endTime)}</td>
        <td>{renderBreakMinutes entry.breakMinutes}</td>
        <td>{renderDuration entry}</td>
        <td>{renderApprovalBadge entry}{renderApprovalAction entry}</td>
        <td class="text-end">
            {renderEditActions entry canEdit}
        </td>
    </tr>
|]
    where
        staffName = case find (\s -> unpackId s.id == entry.staffId) staffMembers of
            Just staff -> staff.firstName <> " " <> staff.lastName
            Nothing    -> "Unknown" :: Text
        canEdit = currentUserIsManager || isWithinEditWindow today entry.workedOn editWindowDays

renderEditActions :: TimesheetEntry -> Bool -> Html
renderEditActions entry canEdit
    | canEdit = [hsx|
        <a href={EditTimesheetEntryAction entry.id} class="btn btn-sm btn-outline-secondary me-1">Edit</a>
        <a href={DeleteTimesheetEntryAction entry.id} class="btn btn-sm btn-outline-danger js-delete js-delete-no-confirm">Delete</a>
    |]
    | otherwise = mempty

renderApprovalAction :: (?context :: ControllerContext) => TimesheetEntry -> Html
renderApprovalAction entry
    | not currentUserIsManager = mempty
    | entry.isApproved = [hsx|
        <a href={UnapproveTimesheetEntryAction entry.id} class="btn btn-sm btn-outline-warning ms-1">Unapprove</a>
    |]
    | otherwise = [hsx|
        <a href={ApproveTimesheetEntryAction entry.id} class="btn btn-sm btn-outline-success ms-1">Approve</a>
    |]

renderBreakMinutes :: Int -> Html
renderBreakMinutes 0    = [hsx|—|]
renderBreakMinutes mins = [hsx|{show mins}m|]

renderDuration :: TimesheetEntry -> Html
renderDuration entry =
    let startMins = todHour entry.startTime * 60 + todMin entry.startTime
        endMins = todHour entry.endTime * 60 + todMin entry.endTime
        netMins = (endMins - startMins) - entry.breakMinutes
        hours = netMins `div` 60
        mins = netMins `mod` 60
    in [hsx|{show hours}h {show mins}m|]

renderApprovalBadge :: TimesheetEntry -> Html
renderApprovalBadge entry
    | entry.isApproved = [hsx|<span class="badge bg-success">Approved</span>|]
    | otherwise = [hsx|<span class="badge bg-warning text-dark">Pending</span>|]
