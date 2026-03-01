module Web.View.Timesheets.New where

import Web.View.Prelude

data NewView = NewView
    { timesheetEntry :: TimesheetEntry
    , staffMembers   :: [Staff]
    }

instance View NewView where
    html NewView { .. } = [hsx|
        <h1>New Timesheet Entry</h1>
        {renderTimesheetForm timesheetEntry staffMembers CreateTimesheetEntryAction}
        {renderQuarterHourTimePickerModal}
    |]
