module Web.View.Timesheets.Index where

import Web.View.Prelude

data IndexView = IndexView
    { entries      :: [TimesheetEntry]
    , staffMembers :: [Staff]
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h1>Timesheets</h1>
            <a href={NewTimesheetEntryAction} class="btn btn-primary">New Entry</a>
        </div>

        {if null entries
            then renderEmptyState
            else renderEntriesTable entries staffMembers
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

renderEntriesTable :: [TimesheetEntry] -> [Staff] -> Html
renderEntriesTable entries staffMembers = [hsx|
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
                {forEach entries (renderEntryRow staffMembers)}
            </tbody>
        </table>
    </div>
|]

renderEntryRow :: [Staff] -> TimesheetEntry -> Html
renderEntryRow staffMembers entry = [hsx|
    <tr>
        <td>{entry.workedOn}</td>
        <td>{staffName}</td>
        <td>{storageTimeToDisplayLabel (timeOfDayToStorageValue entry.startTime)}</td>
        <td>{storageTimeToDisplayLabel (timeOfDayToStorageValue entry.endTime)}</td>
        <td>{renderBreakMinutes entry.breakMinutes}</td>
        <td>{renderDuration entry}</td>
        <td>{renderApprovalBadge entry}</td>
        <td class="text-end">
            <a href={EditTimesheetEntryAction entry.id} class="btn btn-sm btn-outline-secondary me-1">Edit</a>
            <a href={DeleteTimesheetEntryAction entry.id} class="btn btn-sm btn-outline-danger js-delete js-delete-no-confirm">Delete</a>
        </td>
    </tr>
|]
    where
        staffName = case find (\s -> unpackId s.id == entry.staffId) staffMembers of
            Just staff -> staff.firstName <> " " <> staff.lastName
            Nothing    -> "Unknown" :: Text

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
