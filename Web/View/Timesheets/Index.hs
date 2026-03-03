module Web.View.Timesheets.Index where

import Application.Helper.Controller (isWithinEditWindow, shiftDurationMinutes)
import Application.Helper.Pay (TimesheetPaySummary (..), timesheetEntryIdKey)
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Data.Time.Calendar (Day, addDays)
import Data.Time.Format (defaultTimeLocale, formatTime)
import Web.View.Prelude

data IndexView = IndexView
    { entries               :: [TimesheetEntry]
    , staffMembers          :: [Staff]
    , paySummariesByEntryId :: Map.Map Text TimesheetPaySummary
    , today                 :: Day
    , editWindowDays        :: Int
    , weekOffset            :: Int
    , weekStartDate         :: Day
    , weekEndDate           :: Day
    }

timesheetWeekShellId :: Text
timesheetWeekShellId = "timesheet-week-shell"

instance View IndexView where
    html = renderTimesheetWeekShell

renderTimesheetWeekShell :: IndexView -> Html
renderTimesheetWeekShell IndexView { .. } = [hsx|
    <section id={timesheetWeekShellId} hx-history-elt="true">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <div>
                <h1 class="mb-0">Timesheets</h1>
                <p class="app-muted mb-0">{formatDateDisplay weekStartDate} to {formatDateDisplay weekEndDate}</p>
            </div>
            <div class="d-flex gap-2 align-items-center">
                {renderTimesheetWeekNavigationLink "<" (pathTo (ShowTimesheetWeekAction (weekOffset - 1)))}
                {renderTimesheetWeekNavigationLink "this week" (pathTo TimesheetsAction)}
                {renderTimesheetWeekNavigationLink ">" (pathTo (ShowTimesheetWeekAction (weekOffset + 1)))}
            </div>
        </div>

        <div class="d-flex flex-column gap-3">
            {forEach [0 .. 6] (renderDaySection entries staffMembers paySummariesByEntryId today editWindowDays weekOffset weekStartDate)}
        </div>
    </section>
|]

renderTimesheetWeekNavigationLink :: Text -> Text -> Html
renderTimesheetWeekNavigationLink label url =
    renderPartialNavigationLink
        PartialNavigationLink
            { partialNavigationLabel = label
            , partialNavigationUrl = url
            , partialNavigationTargetId = timesheetWeekShellId
            , partialNavigationSelectId = Just timesheetWeekShellId
            , partialNavigationClass = "btn btn-outline-secondary"
            , partialNavigationSwap = "outerHTML"
            , partialNavigationSync = Just ("#" <> timesheetWeekShellId <> ":replace")
            , partialNavigationPushUrl = True
            }

renderDaySection :: (?context :: ControllerContext) => [TimesheetEntry] -> [Staff] -> Map.Map Text TimesheetPaySummary -> Day -> Int -> Int -> Day -> Int -> Html
renderDaySection =
    renderDaySectionWithSwap Nothing

renderDaySectionOob :: (?context :: ControllerContext) => [TimesheetEntry] -> [Staff] -> Map.Map Text TimesheetPaySummary -> Day -> Int -> Int -> Day -> Int -> Html
renderDaySectionOob =
    renderDaySectionWithSwap (Just "outerHTML")

renderDaySectionWithSwap :: (?context :: ControllerContext) => Maybe Text -> [TimesheetEntry] -> [Staff] -> Map.Map Text TimesheetPaySummary -> Day -> Int -> Int -> Day -> Int -> Html
renderDaySectionWithSwap maybeSwapOob entries staffMembers paySummariesByEntryId today editWindowDays weekOffset weekStartDate dayOffset = [hsx|
    <section id={timesheetDaySectionDomId dayOffset} class="app-panel" hx-swap-oob={maybeSwapOob}>
        <div class="app-panel-body">
            <div class="d-flex justify-content-between align-items-center mb-3">
                <div>
                    <h2 class="h5 mb-0">{weekdayLabel}</h2>
                    <p class="app-muted mb-0">{formatDateDisplay dayDate}</p>
                </div>
                <a href={newEntryUrl}
                   class="btn btn-sm btn-primary"
                   hx-get={newEntryUrl}
                   hx-target={"#" <> dialogOverlayMountId}
                   hx-swap="innerHTML"
                   hx-push-url="false">
                    Add Timesheet
                </a>
            </div>

            {renderDayEntries dayEntries staffMembers paySummariesByEntryId today editWindowDays weekOffset}
        </div>
    </section>
|]
    where
        dayDate = addDays (toInteger dayOffset) weekStartDate
        dayEntries = filter (\entry -> entry.workedOn == dayDate) entries
        weekdayLabel = Text.pack (formatTime defaultTimeLocale "%A" dayDate)
        newEntryUrl =
            appendQueryParams
                (pathTo NewTimesheetEntryAction)
                [ ("weekOffset", tshow weekOffset)
                , ("workedOn", tshow dayDate)
                ]

timesheetDaySectionDomId :: Int -> Text
timesheetDaySectionDomId dayOffset = "timesheet-day-section-" <> tshow dayOffset

renderDayEntries :: (?context :: ControllerContext) => [TimesheetEntry] -> [Staff] -> Map.Map Text TimesheetPaySummary -> Day -> Int -> Int -> Html
renderDayEntries dayEntries staffMembers paySummariesByEntryId today editWindowDays weekOffset
    | null dayEntries = [hsx|<p class="app-muted mb-0">No entries for this day.</p>|]
    | otherwise = [hsx|
        <div class="d-flex flex-column gap-2">
            {forEach dayEntries (renderEntryCard staffMembers paySummariesByEntryId today editWindowDays weekOffset)}
        </div>
    |]

renderEntryCard :: (?context :: ControllerContext) => [Staff] -> Map.Map Text TimesheetPaySummary -> Day -> Int -> Int -> TimesheetEntry -> Html
renderEntryCard staffMembers paySummariesByEntryId today editWindowDays weekOffset entry = [hsx|
    <div class="border rounded p-3">
        <div class="d-flex justify-content-between align-items-start gap-3">
            <div>
                <div class="fw-semibold">{staffName}</div>
                <div class="small app-muted">
                    {storageTimeToDisplayLabel (timeOfDayToStorageValue entry.startTime)} - {storageTimeToDisplayLabel (timeOfDayToStorageValue entry.endTime)}
                </div>
                <div class="small app-muted">Break: {renderBreakSummary entry}</div>
                <div class="small">Duration: {renderDuration entry}</div>
                <div class="small">Pay: {renderPaySummary paySummary}</div>
            </div>

            <div class="text-end">
                <div class="mb-2">{renderApprovalBadge entry}</div>
                {renderApprovalAction entry weekOffset}
                {renderEditActions entry canEdit weekOffset}
            </div>
        </div>
    </div>
|]
    where
        staffName = case find (\s -> unpackId (get #id s) == entry.staffId) staffMembers of
            Just staff -> staff.firstName <> " " <> staff.lastName
            Nothing    -> "Unknown" :: Text
        paySummary = Map.lookup (timesheetEntryIdKey (get #id entry)) paySummariesByEntryId
        canEdit = currentUserIsManager || isWithinEditWindow today entry.workedOn editWindowDays

renderPaySummary :: Maybe TimesheetPaySummary -> Html
renderPaySummary maybeSummary =
    case maybeSummary of
        Nothing -> [hsx|<span class="app-muted">Unavailable</span>|]
        Just summary -> [hsx|
            <span>{renderMinutes summary.paidMinutes}</span>
            <span class="app-muted"> ({show summary.segmentCount} segment(s))</span>
            {when summary.weekendApplied renderWeekendNotice}
            {when summary.hasStackedMultiplier renderStackedBadge}
        |]
    where
        renderMinutes totalMinutes =
            let hours = totalMinutes `div` 60
                mins = totalMinutes `mod` 60
             in tshow hours <> "h " <> tshow mins <> "m"
        renderWeekendNotice = [hsx|<span class="app-muted"> weekend</span>|]
        renderStackedBadge = [hsx|<span class="badge bg-info-subtle text-info-emphasis ms-1">stacked</span>|]

renderEditActions :: TimesheetEntry -> Bool -> Int -> Html
renderEditActions entry canEdit weekOffset
    | canEdit = [hsx|
        <a href={editUrl}
           class="btn btn-sm btn-outline-secondary me-1"
           hx-get={editUrl}
           hx-target={"#" <> dialogOverlayMountId}
           hx-swap="innerHTML"
           hx-push-url="false">
            Edit
        </a>
        <a href={deleteUrl} class="btn btn-sm btn-outline-danger js-delete js-delete-no-confirm">Delete</a>
    |]
    | otherwise = mempty
    where
        editUrl = appendQueryParams (pathTo (EditTimesheetEntryAction entry.id)) [("weekOffset", tshow weekOffset)]
        deleteUrl = appendQueryParams (pathTo (DeleteTimesheetEntryAction entry.id)) [("weekOffset", tshow weekOffset)]

renderApprovalAction :: (?context :: ControllerContext) => TimesheetEntry -> Int -> Html
renderApprovalAction entry weekOffset
    | not currentUserIsManager = mempty
    | entry.isApproved = [hsx|
        <form method="POST" action={UnapproveTimesheetEntryAction entry.id} class="d-inline me-1">
            <input type="hidden" name="weekOffset" value={tshow weekOffset} />
            <button type="submit" class="btn btn-sm btn-outline-warning">Unapprove</button>
        </form>
    |]
    | otherwise = [hsx|
        <form method="POST" action={ApproveTimesheetEntryAction entry.id} class="d-inline me-1">
            <input type="hidden" name="weekOffset" value={tshow weekOffset} />
            <button type="submit" class="btn btn-sm btn-outline-success">Approve</button>
        </form>
    |]

renderBreakSummary :: TimesheetEntry -> Text
renderBreakSummary entry
    | not entry.hadBreak = "None"
    | otherwise =
        case (entry.breakStartTime, entry.breakEndTime) of
            (Just breakStart, Just breakEnd) ->
                storageTimeToDisplayLabel (timeOfDayToStorageValue breakStart)
                    <> " - "
                    <> storageTimeToDisplayLabel (timeOfDayToStorageValue breakEnd)
            _ -> "Invalid"

renderDuration :: TimesheetEntry -> Html
renderDuration entry =
    let netMins = shiftDurationMinutes entry.startTime entry.endTime - entry.breakMinutes
        hours = netMins `div` 60
        mins = netMins `mod` 60
    in [hsx|{show hours}h {show mins}m|]

renderApprovalBadge :: TimesheetEntry -> Html
renderApprovalBadge entry
    | entry.isApproved = [hsx|<span class="badge bg-success">Approved</span>|]
    | otherwise = [hsx|<span class="badge bg-warning text-dark">Pending</span>|]
