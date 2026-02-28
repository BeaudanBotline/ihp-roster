module Application.Helper.View where

import Application.Helper.Controller (UserRole (..), hasRole, parseUserRole)
import qualified Data.Text as Text
import Data.Time.Format (defaultTimeLocale, formatTime, parseTimeM)
import Data.Time.LocalTime (TimeOfDay (..))
import Generated.Types
import IHP.ViewPrelude

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
