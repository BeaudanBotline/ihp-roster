module Web.Controller.Timesheets where

import Web.Controller.Prelude
import Web.View.Timesheets.Edit
import Web.View.Timesheets.Index
import Web.View.Timesheets.New

instance Controller TimesheetsController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted

    action TimesheetsAction = do
        (entries, staffMembers) <- fetchTimesheetData
        config <- fetchVenueConfig
        now <- getCurrentTime
        let today = utctDay now
        let editWindowDays = config.staffTimesheetEditWindowDays
        render IndexView { .. }

    action NewTimesheetEntryAction = do
        staffMembers <- fetchStaffForForm
        case staffMembers of
            [] -> do
                setErrorMessage "No staff record found. Contact an administrator."
                redirectTo TimesheetsAction
            _ -> do
                let timesheetEntry = newRecord @TimesheetEntry
                render NewView { .. }

    action CreateTimesheetEntryAction = do
        staffMembers <- fetchStaffForForm
        let timesheetEntry = newRecord @TimesheetEntry
                |> buildTimesheetEntry
        timesheetEntry
            |> ifValid \case
                Left timesheetEntry -> render NewView { .. }
                Right timesheetEntry -> do
                    timesheetEntry <- timesheetEntry |> createRecord
                    setSuccessMessage "Timesheet entry created"
                    redirectTo TimesheetsAction

    action EditTimesheetEntryAction { timesheetEntryId } = do
        timesheetEntry <- fetch timesheetEntryId
        ensureEditWindowOrManager timesheetEntry.workedOn
        staffMembers <- fetchStaffForForm
        render EditView { .. }

    action UpdateTimesheetEntryAction { timesheetEntryId } = do
        staffMembers <- fetchStaffForForm
        timesheetEntry <- fetch timesheetEntryId
        ensureEditWindowOrManager timesheetEntry.workedOn
        let wasApproved = timesheetEntry.isApproved
        timesheetEntry
            |> buildTimesheetEntry
            |> ifValid \case
                Left timesheetEntry -> render EditView { .. }
                Right timesheetEntry -> do
                    timesheetEntry <- timesheetEntry
                        |> resetApprovalOnEdit wasApproved
                        |> updateRecord
                    when wasApproved do
                        setSuccessMessage "Timesheet entry updated (approval reset)"
                    unless wasApproved do
                        setSuccessMessage "Timesheet entry updated"
                    redirectTo TimesheetsAction

    action DeleteTimesheetEntryAction { timesheetEntryId } = do
        timesheetEntry <- fetch timesheetEntryId
        ensureEditWindowOrManager timesheetEntry.workedOn
        deleteRecord timesheetEntry
        setSuccessMessage "Timesheet entry deleted"
        redirectTo TimesheetsAction

    action ApproveTimesheetEntryAction { timesheetEntryId } = do
        ensureManagerRole
        timesheetEntry <- fetch timesheetEntryId
        now <- getCurrentTime
        timesheetEntry
            |> set #isApproved True
            |> set #approvedAt (Just now)
            |> set #approvedByUserId (Just (unpackId currentUser.id))
            |> updateRecord
        setSuccessMessage "Timesheet entry approved"
        redirectTo TimesheetsAction

    action UnapproveTimesheetEntryAction { timesheetEntryId } = do
        ensureManagerRole
        timesheetEntry <- fetch timesheetEntryId
        timesheetEntry
            |> set #isApproved False
            |> set #approvedAt Nothing
            |> set #approvedByUserId Nothing
            |> updateRecord
        setSuccessMessage "Timesheet entry unapproved"
        redirectTo TimesheetsAction

fetchTimesheetData :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO ([TimesheetEntry], [Staff])
fetchTimesheetData = do
    staffMembers <- query @Staff |> orderByAsc #lastName |> fetch
    entries <- if hasRole ManagerRole
        then query @TimesheetEntry |> orderByDesc #workedOn |> fetch
        else do
            maybeStaff <- fetchCurrentUserStaff
            case maybeStaff of
                Nothing -> pure []
                Just staff -> query @TimesheetEntry
                    |> filterWhere (#staffId, unpackId staff.id)
                    |> orderByDesc #workedOn
                    |> fetch
    pure (entries, staffMembers)

fetchStaffForForm :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO [Staff]
fetchStaffForForm =
    if hasRole ManagerRole
        then query @Staff |> filterWhere (#isActive, True) |> orderByAsc #lastName |> fetch
        else do
            maybeStaff <- fetchCurrentUserStaff
            pure $ maybeToList maybeStaff

fetchCurrentUserStaff :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO (Maybe Staff)
fetchCurrentUserStaff = query @Staff
    |> filterWhere (#userId, Just (unpackId currentUser.id))
    |> fetchOneOrNothing

resetApprovalOnEdit :: Bool -> TimesheetEntry -> TimesheetEntry
resetApprovalOnEdit wasApproved entry
    | wasApproved = entry
        |> set #isApproved False
        |> set #approvedAt Nothing
        |> set #approvedByUserId Nothing
    | otherwise = entry

buildTimesheetEntry :: (?context :: ControllerContext) => TimesheetEntry -> TimesheetEntry
buildTimesheetEntry entry =
    entry
        |> fill @'["staffId", "workedOn", "breakMinutes"]
        |> parseAndSetStartTime
        |> parseAndSetEndTime
        |> validateField #breakMinutes (\mins ->
            if isQuarterHourMinutes mins
                then Success
                else Failure "Break must be in 15-minute increments")
        |> validateTimingConstraints
    where
        parseAndSetStartTime record =
            case parseTimeParam (paramOrDefault "" "startTime") of
                Just tod -> record
                    |> set #startTime tod
                    |> validateField #startTime (\t ->
                        if isQuarterHourTime t
                            then Success
                            else Failure "Start time must be on a 15-minute increment")
                Nothing -> record |> attachFailure #startTime "Please select a start time"

        parseAndSetEndTime record =
            case parseTimeParam (paramOrDefault "" "endTime") of
                Just tod -> record
                    |> set #endTime tod
                    |> validateField #endTime (\t ->
                        if isQuarterHourTime t
                            then Success
                            else Failure "End time must be on a 15-minute increment")
                Nothing -> record |> attachFailure #endTime "Please select an end time"

        validateTimingConstraints record =
            let duration = shiftDurationMinutes record.startTime record.endTime
            in record
                |> (\r -> if duration <= 0
                    then r |> attachFailure #endTime "End time must be after start time"
                    else r)
                |> (\r -> if duration > 0 && record.breakMinutes > duration
                    then r |> attachFailure #breakMinutes "Break cannot exceed shift duration"
                    else r)
                |> (\r -> if duration > 960
                    then r |> attachFailure #endTime "Shift cannot exceed 16 hours"
                    else r)
