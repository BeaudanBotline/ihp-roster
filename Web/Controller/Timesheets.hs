module Web.Controller.Timesheets where

import Application.Helper.Pay (fetchTimesheetPaySummariesForEntries)
import Data.Coerce (coerce)
import Data.Time.Calendar (Day, addDays, diffDays)
import Data.Time.Clock (getCurrentTime, utctDay)
import Web.Controller.Prelude
import Web.View.Timesheets.Edit
import Web.View.Timesheets.Index
import Web.View.Timesheets.New

instance Controller TimesheetsController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted

    action TimesheetsAction = do
        currentOffset <- currentTimesheetWeekOffset
        redirectTo ShowTimesheetWeekAction { weekOffset = currentOffset }

    action ShowTimesheetWeekAction { weekOffset } = do
        venueConfig <- fetchVenueConfig
        let weekStartDate = addDays (toInteger (weekOffset * 7)) venueConfig.weekOffsetEpoch
        let weekEndDate = addDays 6 weekStartDate

        (entries, staffMembers) <- fetchTimesheetDataForWeek weekStartDate weekEndDate
        paySummariesByEntryId <- fetchTimesheetPaySummariesForEntries entries

        now <- getCurrentTime
        let today = utctDay now
        let editWindowDays = venueConfig.staffTimesheetEditWindowDays
        render IndexView { .. }

    action NewTimesheetEntryAction = do
        weekOffset <- weekOffsetFromParamOrCurrent
        staffMembers <- fetchStaffForForm
        currentUserStaff <- fetchCurrentUserStaff
        let maybeWorkedOn = paramOrNothing @Day "workedOn"

        case (staffMembers, maybeWorkedOn) of
            ([], _) -> do
                setErrorMessage "No staff record found. Contact an administrator."
                redirectTo ShowTimesheetWeekAction { weekOffset }
            (_, Nothing) -> do
                setErrorMessage "Please choose a day before creating a timesheet entry."
                redirectTo ShowTimesheetWeekAction { weekOffset }
            (_, Just workedOn) -> do
                let timesheetEntry =
                        newRecord @TimesheetEntry
                            |> (\entry -> maybe entry (\staff -> set #staffId (unpackId (get #id staff)) entry) currentUserStaff)
                            |> set #workedOn workedOn
                            |> set #hadBreak False
                            |> set #breakStartTime Nothing
                            |> set #breakEndTime Nothing
                            |> set #breakMinutes 0
                setModal NewView { .. }
                jumpToAction ShowTimesheetWeekAction { weekOffset }

    action CreateTimesheetEntryAction = do
        weekOffset <- weekOffsetFromParamOrCurrent
        staffMembers <- fetchStaffForForm
        let timesheetEntry =
                newRecord @TimesheetEntry
                    |> buildTimesheetEntry

        timesheetEntry
            |> ifValid \case
                Left timesheetEntry -> do
                    setModal NewView { .. }
                    jumpToAction ShowTimesheetWeekAction { weekOffset }
                Right timesheetEntry -> do
                    ensureStaffAssignmentAllowed timesheetEntry.staffId
                    _ <- timesheetEntry |> createRecord
                    setSuccessMessage "Timesheet entry created"
                    redirectTo ShowTimesheetWeekAction { weekOffset }

    action EditTimesheetEntryAction { timesheetEntryId } = do
        timesheetEntry <- fetch timesheetEntryId
        ensureTimesheetVisibility timesheetEntry
        ensureEditWindowOrManager timesheetEntry.workedOn

        weekOffset <- weekOffsetFromParamOrEntry timesheetEntry.workedOn
        staffMembers <- fetchStaffForForm
        setModal EditView { .. }
        jumpToAction ShowTimesheetWeekAction { weekOffset }

    action UpdateTimesheetEntryAction { timesheetEntryId } = do
        timesheetEntry <- fetch timesheetEntryId
        ensureTimesheetVisibility timesheetEntry
        ensureEditWindowOrManager timesheetEntry.workedOn

        weekOffset <- weekOffsetFromParamOrEntry timesheetEntry.workedOn
        staffMembers <- fetchStaffForForm

        let wasApproved = timesheetEntry.isApproved
        timesheetEntry
            |> buildTimesheetEntry
            |> ifValid \case
                Left timesheetEntry -> do
                    setModal EditView { .. }
                    jumpToAction ShowTimesheetWeekAction { weekOffset }
                Right timesheetEntry -> do
                    ensureStaffAssignmentAllowed timesheetEntry.staffId
                    _ <- timesheetEntry
                        |> resetApprovalOnEdit wasApproved
                        |> updateRecord
                    when wasApproved do
                        setSuccessMessage "Timesheet entry updated (approval reset)"
                    unless wasApproved do
                        setSuccessMessage "Timesheet entry updated"
                    redirectTo ShowTimesheetWeekAction { weekOffset }

    action DeleteTimesheetEntryAction { timesheetEntryId } = do
        timesheetEntry <- fetch timesheetEntryId
        ensureTimesheetVisibility timesheetEntry
        ensureEditWindowOrManager timesheetEntry.workedOn

        weekOffset <- weekOffsetFromParamOrEntry timesheetEntry.workedOn
        deleteRecord timesheetEntry
        setSuccessMessage "Timesheet entry deleted"
        redirectTo ShowTimesheetWeekAction { weekOffset }

    action ApproveTimesheetEntryAction { timesheetEntryId } = do
        ensureManagerRole
        timesheetEntry <- fetch timesheetEntryId
        weekOffset <- weekOffsetFromParamOrEntry timesheetEntry.workedOn

        now <- getCurrentTime
        timesheetEntry
            |> set #isApproved True
            |> set #approvedAt (Just now)
            |> set #approvedByUserId (Just (unpackId (get #id currentUser)))
            |> updateRecord

        setSuccessMessage "Timesheet entry approved"
        redirectTo ShowTimesheetWeekAction { weekOffset }

    action UnapproveTimesheetEntryAction { timesheetEntryId } = do
        ensureManagerRole
        timesheetEntry <- fetch timesheetEntryId
        weekOffset <- weekOffsetFromParamOrEntry timesheetEntry.workedOn

        timesheetEntry
            |> set #isApproved False
            |> set #approvedAt Nothing
            |> set #approvedByUserId Nothing
            |> updateRecord

        setSuccessMessage "Timesheet entry unapproved"
        redirectTo ShowTimesheetWeekAction { weekOffset }

fetchTimesheetDataForWeek :: (?modelContext :: ModelContext, ?context :: ControllerContext) => Day -> Day -> IO ([TimesheetEntry], [Staff])
fetchTimesheetDataForWeek weekStartDate weekEndDate = do
    staffMembers <- query @Staff |> orderByAsc #lastName |> fetch

    let weekDays = [weekStartDate .. weekEndDate]

    entries <-
        if hasRole ManagerRole
            then
                query @TimesheetEntry
                    |> filterWhereIn (#workedOn, weekDays)
                    |> orderByAsc #workedOn
                    |> orderByAsc #startTime
                    |> fetch
            else do
                maybeStaff <- fetchCurrentUserStaff
                case maybeStaff of
                    Nothing -> pure []
                    Just staff ->
                        query @TimesheetEntry
                            |> filterWhere (#staffId, unpackId (get #id staff))
                            |> filterWhereIn (#workedOn, weekDays)
                            |> orderByAsc #workedOn
                            |> orderByAsc #startTime
                            |> fetch

    pure (entries, staffMembers)

fetchStaffForForm :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO [Staff]
fetchStaffForForm =
    if hasRole ManagerRole
        then query @Staff |> filterWhere (#isActive, True) |> orderByAsc #lastName |> fetch
        else maybeToList <$> fetchCurrentUserStaff

fetchCurrentUserStaff :: (?modelContext :: ModelContext, ?context :: ControllerContext) => IO (Maybe Staff)
fetchCurrentUserStaff =
    query @Staff
        |> filterWhere (#userId, Just (coerce (get #id currentUser)))
        |> fetchOneOrNothing

ensureTimesheetVisibility :: (?context :: ControllerContext, ?modelContext :: ModelContext) => TimesheetEntry -> IO ()
ensureTimesheetVisibility entry =
    unless (hasRole ManagerRole) do
        maybeStaff <- fetchCurrentUserStaff
        let ownsEntry = maybe False (\staff -> unpackId (get #id staff) == entry.staffId) maybeStaff
        accessDeniedUnless ownsEntry

ensureStaffAssignmentAllowed :: (?context :: ControllerContext, ?modelContext :: ModelContext) => UUID -> IO ()
ensureStaffAssignmentAllowed staffId =
    unless (hasRole ManagerRole) do
        maybeStaff <- fetchCurrentUserStaff
        let isOwnStaff = maybe False (\staff -> unpackId (get #id staff) == staffId) maybeStaff
        accessDeniedUnless isOwnStaff

resetApprovalOnEdit :: Bool -> TimesheetEntry -> TimesheetEntry
resetApprovalOnEdit wasApproved entry
    | wasApproved =
        entry
            |> set #isApproved False
            |> set #approvedAt Nothing
            |> set #approvedByUserId Nothing
    | otherwise = entry

buildTimesheetEntry :: (?context :: ControllerContext) => TimesheetEntry -> TimesheetEntry
buildTimesheetEntry entry =
    entry
        |> fill @'["staffId", "workedOn"]
        |> parseAndSetStartTime
        |> parseAndSetEndTime
        |> set #hadBreak hadBreak
        |> applyBreakFields
        |> validateTimingConstraints
    where
        hadBreak = isJust (paramOrNothing @Text "hadBreak")

        parseAndSetStartTime record =
            case parseTimeParam (paramOrDefault "" "startTime") of
                Just tod ->
                    record
                        |> set #startTime tod
                        |> validateField #startTime
                            (\t ->
                                if isQuarterHourTime t
                                    then Success
                                    else Failure "Shift start must be on a 15-minute increment"
                            )
                Nothing -> record |> attachFailure #startTime "Please select a shift start time"

        parseAndSetEndTime record =
            case parseTimeParam (paramOrDefault "" "endTime") of
                Just tod ->
                    record
                        |> set #endTime tod
                        |> validateField #endTime
                            (\t ->
                                if isQuarterHourTime t
                                    then Success
                                    else Failure "Shift end must be on a 15-minute increment"
                            )
                Nothing -> record |> attachFailure #endTime "Please select a shift end time"

        applyBreakFields record
            | not hadBreak =
                record
                    |> set #breakStartTime Nothing
                    |> set #breakEndTime Nothing
                    |> set #breakMinutes 0
            | otherwise =
                record
                    |> set #breakMinutes 0
                    |> parseAndSetBreakStart
                    |> parseAndSetBreakEnd

        parseAndSetBreakStart record =
            case parseTimeParam (paramOrDefault "" "breakStartTime") of
                Just tod ->
                    record
                        |> set #breakStartTime (Just tod)
                        |> validateField #breakStartTime
                            (\value ->
                                case value of
                                    Just t ->
                                        if isQuarterHourTime t
                                            then Success
                                            else Failure "Break start must be on a 15-minute increment"
                                    Nothing -> Failure "Please select a break start time"
                            )
                Nothing ->
                    record
                        |> set #breakStartTime Nothing
                        |> attachFailure #breakStartTime "Please select a break start time"

        parseAndSetBreakEnd record =
            case parseTimeParam (paramOrDefault "" "breakEndTime") of
                Just tod ->
                    record
                        |> set #breakEndTime (Just tod)
                        |> validateField #breakEndTime
                            (\value ->
                                case value of
                                    Just t ->
                                        if isQuarterHourTime t
                                            then Success
                                            else Failure "Break end must be on a 15-minute increment"
                                    Nothing -> Failure "Please select a break end time"
                            )
                Nothing ->
                    record
                        |> set #breakEndTime Nothing
                        |> attachFailure #breakEndTime "Please select a break end time"

        validateTimingConstraints record =
            let shiftStart = normalizeShiftMinuteOfDay record.startTime
                shiftEnd = normalizeShiftMinuteOfDay record.endTime
                duration = shiftEnd - shiftStart
             in record
                    |> (\r ->
                            if duration <= 0
                                then r |> attachFailure #endTime "Shift end must be after shift start"
                                else r
                       )
                    |> (\r ->
                            if duration > 960
                                then r |> attachFailure #endTime "Shift cannot exceed 16 hours"
                                else r
                       )
                    |> validateBreakTiming shiftStart shiftEnd duration

        validateBreakTiming shiftStart shiftEnd shiftDuration record
            | not record.hadBreak =
                record
                    |> set #breakStartTime Nothing
                    |> set #breakEndTime Nothing
                    |> set #breakMinutes 0
            | otherwise =
                case (record.breakStartTime, record.breakEndTime) of
                    (Just breakStart, Just breakEnd) ->
                        let breakStartMinute = normalizeShiftMinuteOfDay breakStart
                            breakEndMinute = normalizeShiftMinuteOfDay breakEnd
                            breakDuration = breakEndMinute - breakStartMinute
                            withOrderValidation =
                                if breakDuration <= 0
                                    then record |> attachFailure #breakEndTime "Break end must be after break start"
                                    else record
                            withContainmentValidation =
                                if breakStartMinute <= shiftStart || breakEndMinute >= shiftEnd
                                    then
                                        withOrderValidation
                                            |> attachFailure #breakStartTime "Break must be strictly inside the shift"
                                            |> attachFailure #breakEndTime "Break must be strictly inside the shift"
                                    else withOrderValidation
                         in if breakDuration > 0 && breakDuration < shiftDuration && breakStartMinute > shiftStart && breakEndMinute < shiftEnd
                                then withContainmentValidation |> set #breakMinutes breakDuration
                                else withContainmentValidation
                    _ -> record

weekOffsetFromParamOrCurrent :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO Int
weekOffsetFromParamOrCurrent = do
    currentOffset <- currentTimesheetWeekOffset
    pure (paramOrDefault currentOffset "weekOffset")

weekOffsetFromParamOrEntry :: (?context :: ControllerContext, ?modelContext :: ModelContext) => Day -> IO Int
weekOffsetFromParamOrEntry workedOnDate = do
    venueConfig <- fetchVenueConfig
    let entryOffset = weekOffsetForDay venueConfig.weekOffsetEpoch workedOnDate
    pure (paramOrDefault entryOffset "weekOffset")

currentTimesheetWeekOffset :: (?modelContext :: ModelContext) => IO Int
currentTimesheetWeekOffset = do
    venueConfig <- fetchVenueConfig
    today <- utctDay <$> getCurrentTime
    pure (weekOffsetForDay venueConfig.weekOffsetEpoch today)

weekOffsetForDay :: Day -> Day -> Int
weekOffsetForDay epoch day = fromInteger (diffDays day epoch `div` 7)
