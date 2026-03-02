module Application.Helper.View where

import Application.Helper.Controller (UserRole (..), hasRole, parseUserRole)
import Data.List (sortBy)
import qualified Data.Text as Text
import Data.Time.Calendar (Day)
import Data.Time.Format (defaultTimeLocale, formatTime, parseTimeM)
import Data.Time.LocalTime (TimeOfDay (..))
import Generated.Types
import IHP.ViewPrelude
import Web.Routes ()
import Web.Types

-- Here you can add functions which are available in all your views

-- | True when the current user has at least manager privileges.
-- Use in views for conditional rendering of management UI.
currentUserIsManager :: (?context :: ControllerContext) => Bool
currentUserIsManager = hasRole ManagerRole

-- | True when the current user is an admin.
-- Use in views for conditional rendering of admin-only UI.
currentUserIsAdmin :: (?context :: ControllerContext) => Bool
currentUserIsAdmin = hasRole AdminRole

-- | True when a staff record is a trial placeholder (no linked user account).
isTrialStaff :: Staff -> Bool
isTrialStaff staff = isNothing staff.userId

linkedActiveStaffForRosterPanel :: [Staff] -> [Staff]
linkedActiveStaffForRosterPanel =
    sortBy sortStaff
        . filter (\staff -> staff.isActive && isJust staff.userId)
    where
        sortStaff left right =
            compare left.firstName right.firstName <> compare left.lastName right.lastName

-- | Shared modal id for the reusable quarter-hour time picker.
timePickerModalId :: Text
timePickerModalId = "quarter-hour-time-picker-modal"

formatDateDisplay :: Day -> Text
formatDateDisplay day = Text.pack (formatTime defaultTimeLocale "%d/%m/%Y" day)

appendQueryParams :: Text -> [(Text, Text)] -> Text
appendQueryParams basePath params
    | null nonEmptyParams = basePath
    | Text.isInfixOf "?" basePath = basePath <> "&" <> renderedParams
    | otherwise = basePath <> "?" <> renderedParams
    where
        nonEmptyParams = filter (not . Text.null . snd) params
        renderedParams = Text.intercalate "&" (map renderParam nonEmptyParams)
        renderParam (key, value) = key <> "=" <> value

-- | Canonical quarter-hour time options from 06:00 through 23:45.
-- Value format is 24-hour HH:MM for storage; label format is 12-hour with AM/PM.
quarterHourTimeOptions :: [(Text, Text)]
quarterHourTimeOptions = quarterHourTimeOptionsInRange (TimeOfDay 6 0 0) (TimeOfDay 23 45 0)

quarterHourTimeOptionsInRange :: TimeOfDay -> TimeOfDay -> [(Text, Text)]
quarterHourTimeOptionsInRange startTime endTime =
    map toOption minuteMarks
    where
        startMinutes = timeOfDayToMinuteOfDay startTime
        endMinutesRaw = timeOfDayToMinuteOfDay endTime
        endMinutes = if endMinutesRaw < startMinutes then endMinutesRaw + 1440 else endMinutesRaw
        minuteMarks = [startMinutes, startMinutes + 15 .. endMinutes]

        toOption totalMinutes =
            let minuteOfDay = totalMinutes `mod` 1440
                (hours, minutes) = minuteOfDay `divMod` 60
                tod = TimeOfDay hours minutes 0
             in (timeOfDayToStorageValue tod, Text.pack (formatTime defaultTimeLocale "%-I:%M %p" tod))

        timeOfDayToMinuteOfDay tod = todHour tod * 60 + todMin tod

-- | Format a TimeOfDay for DB/form storage.
timeOfDayToStorageValue :: TimeOfDay -> Text
timeOfDayToStorageValue tod = Text.pack (formatTime defaultTimeLocale "%H:%M" tod)

-- | Format an optional TimeOfDay for DB/form storage.
optionalTimeOfDayToStorageValue :: Maybe TimeOfDay -> Text
optionalTimeOfDayToStorageValue = maybe "" timeOfDayToStorageValue

-- | Convert a stored HH:MM value to a display label like "6:15 AM".
storageTimeToDisplayLabel :: Text -> Text
storageTimeToDisplayLabel rawValue =
    case parseTimeM True defaultTimeLocale "%H:%M" (cs rawValue) :: Maybe TimeOfDay of
        Just tod -> Text.pack (formatTime defaultTimeLocale "%-I:%M %p" tod)
        Nothing  -> rawValue

renderQuarterHourTimePickerModal :: Html
renderQuarterHourTimePickerModal = [hsx|
    <div class="modal fade"
         id={timePickerModalId}
         tabindex="-1"
         data-default-start-time="06:00"
         data-default-end-time="23:45"
         aria-labelledby="timePickerModalLabel"
         aria-hidden="true">
        <div class="modal-dialog modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="timePickerModalLabel">Select Time</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="time-picker-grid js-time-picker-grid">
                        {forEach quarterHourTimeOptions renderTimePickerOption}
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-outline-secondary js-time-picker-clear">Clear time</button>
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                </div>
            </div>
        </div>
    </div>
|]

renderTimePickerOption :: (Text, Text) -> Html
renderTimePickerOption (value, label) = [hsx|
    <button type="button"
            class="btn btn-outline-secondary time-picker-option js-time-picker-option"
            data-time-value={value}>
        {label}
    </button>
|]

-- | Shared timesheet entry form used by New and Edit views.
renderTimesheetForm :: (?context :: ControllerContext) => TimesheetEntry -> [Staff] -> Int -> TimesheetsController -> Html
renderTimesheetForm entry staffMembers weekOffset action = [hsx|
    <form method="POST" action={action} class="mt-3">
        <input type="hidden" name="weekOffset" value={tshow weekOffset} />
        {renderStaffField entry staffMembers}
        <div class="mb-3">
            <label class="form-label">Day</label>
            <input type="hidden" name="workedOn" value={dateValueIso} />
            <div class="form-control">{dateLabel}</div>
            {renderFieldError entry "workedOn"}
        </div>

        <div class="row mb-3">
            <div class="col">
                <label class="form-label">Shift Start</label>
                {renderTimePickerField "startTime" startTimeValue "06:00" "04:45" False}
                {renderFieldError entry "startTime"}
            </div>
            <div class="col">
                <label class="form-label">Shift End</label>
                {renderTimePickerField "endTime" endTimeValue "06:00" "04:45" False}
                {renderFieldError entry "endTime"}
            </div>
        </div>

        <div class="mb-3">
            <div class="form-check">
                <input
                    id="hadBreak"
                    name="hadBreak"
                    type="checkbox"
                    value="on"
                    class={classes [("form-check-input", True), ("is-invalid", hasErrorFor entry "hadBreak")]}
                    checked={entry.hadBreak}
                    data-break-toggle="true"
                    data-break-target="#timesheet-break-time-fields"
                />
                <label class="form-check-label" for="hadBreak">Had break</label>
            </div>
            {renderFieldError entry "hadBreak"}
        </div>

        <div id="timesheet-break-time-fields" class="row mb-3" hidden={not entry.hadBreak}>
            <div class="col">
                <label class="form-label">Break Start</label>
                {renderTimePickerField "breakStartTime" breakStartTimeValue "06:00" "04:45" (not entry.hadBreak)}
                {renderFieldError entry "breakStartTime"}
            </div>
            <div class="col">
                <label class="form-label">Break End</label>
                {renderTimePickerField "breakEndTime" breakEndTimeValue "06:00" "04:45" (not entry.hadBreak)}
                {renderFieldError entry "breakEndTime"}
            </div>
        </div>
        {renderFieldError entry "breakMinutes"}

        <button type="submit" class="btn btn-primary">Save</button>
        <a href={ShowTimesheetWeekAction weekOffset} class="btn btn-outline-secondary ms-2">Cancel</a>
    </form>
|]
    where
        startTimeValue = timeOfDayToStorageValue entry.startTime
        endTimeValue = timeOfDayToStorageValue entry.endTime
        breakStartTimeValue = optionalTimeOfDayToStorageValue entry.breakStartTime
        breakEndTimeValue = optionalTimeOfDayToStorageValue entry.breakEndTime
        dateValueIso = tshow entry.workedOn :: Text
        dateLabel = formatDateDisplay entry.workedOn

renderStaffField :: (?context :: ControllerContext) => TimesheetEntry -> [Staff] -> Html
renderStaffField entry staffMembers =
    if currentUserIsManager
        then [hsx|
            <div class="mb-3">
                <label for="staffId" class="form-label">Staff Member</label>
                <select name="staffId" id="staffId" class={classes [("form-select", True), ("is-invalid", hasErrorFor entry "staffId")]} required="required">
                    <option value="">Select staff…</option>
                    {forEach staffMembers (renderTimesheetStaffOption entry.staffId)}
                </select>
                {renderFieldError entry "staffId"}
            </div>
        |]
        else [hsx|
            <input type="hidden" name="staffId" value={inputValue entry.staffId} />
        |]

renderTimesheetStaffOption :: UUID -> Staff -> Html
renderTimesheetStaffOption selectedStaffId staff =
    let isSelected = unpackId (get #id staff) == selectedStaffId
    in [hsx|
        <option value={inputValue staff.id} selected={isSelected}>
            {staff.firstName} {staff.lastName}
        </option>
    |]

renderTimePickerField :: Text -> Text -> Text -> Text -> Bool -> Html
renderTimePickerField fieldName currentValue rangeStart rangeEnd disabled =
    let displayLabel = if Text.null currentValue || currentValue == "00:00"
            then "Select time" :: Text
            else storageTimeToDisplayLabel currentValue
        isMuted = Text.null currentValue || currentValue == "00:00"
    in [hsx|
        <div data-time-picker-field="true" data-time-picker-start={rangeStart} data-time-picker-end={rangeEnd} class="d-flex align-items-center">
            <input type="hidden"
                   name={fieldName}
                   value={currentValue}
                   class="js-time-picker-input"
                   disabled={disabled} />
            <button type="button"
                    class="btn btn-outline-secondary js-time-picker-trigger"
                    disabled={disabled}>
                <span class={classes [("js-time-picker-label", True), ("app-muted", isMuted)]}>{displayLabel}</span>
            </button>
        </div>
    |]

renderFieldError :: TimesheetEntry -> Text -> Html
renderFieldError entry fieldName =
    case lookup fieldName entry.meta.annotations of
        Just (TextViolation msg) -> [hsx|<div class="invalid-feedback d-block">{msg}</div>|]
        Just (HtmlViolation msg) -> [hsx|<div class="invalid-feedback d-block">{msg}</div>|]
        Nothing -> mempty

hasErrorFor :: TimesheetEntry -> Text -> Bool
hasErrorFor entry fieldName = isJust (lookup fieldName entry.meta.annotations)

renderTimesheetEntryModal :: Text -> Int -> Html -> Html
renderTimesheetEntryModal title weekOffset formContent =
    renderModal Modal
        { modalTitle = title
        , modalCloseUrl = pathTo (ShowTimesheetWeekAction weekOffset)
        , modalFooter = Nothing
        , modalContent = formContent
        }

renderStaffEditModal :: Text -> Int -> Html -> Html
renderStaffEditModal title weekOffset formContent =
    renderModal Modal
        { modalTitle = title
        , modalCloseUrl = pathTo (ShowRosterWeekAction weekOffset)
        , modalFooter = Nothing
        , modalContent = formContent
        }
