module Application.Helper.View where

import Application.Helper.Controller (UserRole (..), hasRole, parseUserRole)
import qualified Data.Text as Text
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

-- | Shared modal id for the reusable quarter-hour time picker.
timePickerModalId :: Text
timePickerModalId = "quarter-hour-time-picker-modal"

-- | Canonical quarter-hour time options from 06:00 through 23:45.
-- Value format is 24-hour HH:MM for storage; label format is 12-hour with AM/PM.
quarterHourTimeOptions :: [(Text, Text)]
quarterHourTimeOptions = map toOption [6 * 60, (6 * 60) + 15 .. (23 * 60) + 45]
    where
        toOption totalMinutes =
            let (hours, minutes) = totalMinutes `divMod` 60
                tod = TimeOfDay hours minutes 0
             in (timeOfDayToStorageValue tod, Text.pack (formatTime defaultTimeLocale "%-I:%M %p" tod))

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
         aria-labelledby="timePickerModalLabel"
         aria-hidden="true">
        <div class="modal-dialog modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="timePickerModalLabel">Select Start Time</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="time-picker-grid">
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
renderTimesheetForm :: (?context :: ControllerContext) => TimesheetEntry -> [Staff] -> TimesheetsController -> Html
renderTimesheetForm entry staffMembers action = [hsx|
    <form method="POST" action={action} class="mt-3 app-form-width">
        {renderStaffField entry staffMembers}
        <div class="mb-3">
            <label for="workedOn" class="form-label">Date</label>
            <input
                id="workedOn"
                name="workedOn"
                type="date"
                class={classes [("form-control", True), ("is-invalid", hasErrorFor entry "workedOn")]}
                value={dateValue}
                required="required"
            />
            {renderFieldError entry "workedOn"}
        </div>
        <div class="row mb-3">
            <div class="col">
                <label class="form-label">Start Time</label>
                {renderTimePickerField "startTime" startTimeValue}
                {renderFieldError entry "startTime"}
            </div>
            <div class="col">
                <label class="form-label">End Time</label>
                {renderTimePickerField "endTime" endTimeValue}
                {renderFieldError entry "endTime"}
            </div>
        </div>
        <div class="mb-3">
            <label for="breakMinutes" class="form-label">Break</label>
            <select name="breakMinutes" id="breakMinutes" class={classes [("form-select", True), ("is-invalid", hasErrorFor entry "breakMinutes")]}>
                {forEach breakOptions (renderBreakOption entry.breakMinutes)}
            </select>
            {renderFieldError entry "breakMinutes"}
        </div>
        <button type="submit" class="btn btn-primary">Save</button>
        <a href={TimesheetsAction} class="btn btn-outline-secondary ms-2">Cancel</a>
    </form>
|]
    where
        startTimeValue = timeOfDayToStorageValue entry.startTime
        endTimeValue = timeOfDayToStorageValue entry.endTime
        dateValue = tshow entry.workedOn :: Text

renderStaffField :: (?context :: ControllerContext) => TimesheetEntry -> [Staff] -> Html
renderStaffField entry staffMembers =
    if currentUserIsManager
        then [hsx|
            <div class="mb-3">
                <label for="staffId" class="form-label">Staff Member</label>
                <select name="staffId" id="staffId" class="form-select" required="required">
                    <option value="">Select staff…</option>
                    {forEach staffMembers (renderTimesheetStaffOption entry.staffId)}
                </select>
            </div>
        |]
        else [hsx|
            <input type="hidden" name="staffId" value={inputValue entry.staffId} />
        |]

renderTimesheetStaffOption :: UUID -> Staff -> Html
renderTimesheetStaffOption selectedStaffId staff =
    let isSelected = unpackId staff.id == selectedStaffId
    in [hsx|
        <option value={inputValue staff.id} selected={isSelected}>
            {staff.firstName} {staff.lastName}
        </option>
    |]

renderTimePickerField :: Text -> Text -> Html
renderTimePickerField fieldName currentValue =
    let displayLabel = if Text.null currentValue || currentValue == "00:00"
            then "Select time" :: Text
            else storageTimeToDisplayLabel currentValue
        isMuted = Text.null currentValue || currentValue == "00:00"
    in [hsx|
        <div data-time-picker-field="true" class="d-flex align-items-center">
            <input type="hidden"
                   name={fieldName}
                   value={currentValue}
                   class="js-time-picker-input" />
            <button type="button"
                    class="btn btn-outline-secondary js-time-picker-trigger">
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

breakOptions :: [Int]
breakOptions = [0, 15, 30, 45, 60, 75, 90, 105, 120]

renderBreakOption :: Int -> Int -> Html
renderBreakOption selectedMins mins =
    let label = if mins == 0 then "None" :: Text else tshow mins <> " min"
    in [hsx|
        <option value={tshow mins} selected={mins == selectedMins}>{label}</option>
    |]
