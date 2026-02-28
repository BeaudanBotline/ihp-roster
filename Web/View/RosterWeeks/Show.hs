module Web.View.RosterWeeks.Show where

import Data.Coerce (coerce)
import Data.List (find, nub, sort)
import qualified Data.Text as Text
import Data.Time.Calendar (Day)
import qualified Data.Time.Calendar as Calendar
import Data.Time.Format (defaultTimeLocale, formatTime)
import Data.UUID (UUID)
import Web.View.Prelude

data ShowView = ShowView
    { rosterWeek    :: Maybe RosterWeek
    , rosterDays    :: [RosterDay]
    , weekOffset    :: Int
    , weekStartDate :: Day
    , weekEndDate   :: Day
    , staffMembers  :: [Staff]
    , slotNames     :: [SlotName]
    , allSlots      :: [RosterSlot]
    , slotConflicts :: [(Id RosterSlot, [RosterConflict])]
    }

instance View ShowView where
    html ShowView { .. } = [hsx|
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href={DashboardAction}>Dashboard</a></li>
                <li class="breadcrumb-item active">Roster Week {weekOffset}</li>
            </ol>
        </nav>

        <div class="d-flex justify-content-between align-items-center mb-4">
            <div>
                <h1 class="mb-0">Roster Week {weekOffset}</h1>
                <p class="app-muted mb-0">{tshow weekStartDate} to {tshow weekEndDate}</p>
            </div>
            <div class="d-flex gap-2 align-items-center">
                <a href={ShowRosterWeekAction (weekOffset - 1)} class="btn btn-outline-secondary">&larr; Prev Week</a>
                <a href={ShowRosterWeekAction (weekOffset + 1)} class="btn btn-outline-secondary">Next Week &rarr;</a>
            </div>
        </div>

        {renderRosterContentFragment rosterWeek rosterDays weekOffset staffMembers slotNames weekStartDate allSlots slotConflicts}
        {renderQuarterHourTimePickerModal}
    |]

renderRosterContentFragment :: (?context :: ControllerContext) => Maybe RosterWeek -> [RosterDay] -> Int -> [Staff] -> [SlotName] -> Day -> [RosterSlot] -> [(Id RosterSlot, [RosterConflict])] -> Html
renderRosterContentFragment rosterWeek rosterDays weekOffset staffMembers slotNames weekStartDate allSlots slotConflicts = [hsx|
    <div id="roster-content">
        {renderRosterContent rosterWeek rosterDays weekOffset staffMembers slotNames weekStartDate allSlots slotConflicts}
    </div>
|]

renderRosterContent :: (?context :: ControllerContext) => Maybe RosterWeek -> [RosterDay] -> Int -> [Staff] -> [SlotName] -> Day -> [RosterSlot] -> [(Id RosterSlot, [RosterConflict])] -> Html
renderRosterContent Nothing _ weekOffset _ _ _ _ _ = [hsx|
    <div class="alert alert-info d-flex justify-content-between align-items-center shadow-sm">
        <div>
            <strong class="d-block mb-1">No roster exists for this week yet.</strong>
            <p class="mb-0 app-muted small">This week is currently empty. You can create a draft to start assigning staff.</p>
        </div>
        {when currentUserIsManager (renderCreateForm weekOffset)}
    </div>
|]

renderRosterContent (Just rosterWeek) rosterDays _ staffMembers slotNames weekStartDate allSlots slotConflicts = [hsx|
    <div class="card shadow-sm mb-5">
        <div class="card-header d-flex justify-content-between align-items-center py-3">
            <div class="d-flex align-items-center gap-3">
                <span class="fw-bold">Status:</span>
                {renderStatusBadge rosterWeek.isLive}
            </div>
            {when (not rosterWeek.isLive && currentUserIsManager) (renderPublishForm rosterWeek)}
        </div>
        <div class="table-responsive">
            <table class="table table-bordered table-sm mb-0 align-middle roster-grid">
                <thead class="text-center text-uppercase fw-bold roster-grid-head">
                    <tr>
                        <th rowspan="2" class="py-2 roster-day-column">Day / Date</th>
                        {forEach slotNames renderSlotHeaderGroup}
                    </tr>
                    <tr>
                        {forEach slotNames renderSlotSubHeaders}
                    </tr>
                </thead>
                <tbody>
                    {forEach rosterDays (renderRosterDay slotNames staffMembers weekStartDate allSlots slotConflicts)}
                </tbody>
            </table>
        </div>
    </div>
|]

renderSlotHeaderGroup :: SlotName -> Html
renderSlotHeaderGroup slotName = [hsx|
    <th colspan="3" class="py-2 roster-block-header">{slotName.name}</th>
|]

renderSlotSubHeaders :: SlotName -> Html
renderSlotSubHeaders _ =
    mconcat
        [ [hsx|<th class="py-1 roster-subhead roster-col-time">Time</th>|]
        , [hsx|<th class="py-1 roster-subhead roster-col-staff">Staff</th>|]
        , [hsx|<th class="py-1 roster-subhead roster-col-code roster-block-end">Code</th>|]
        ]

renderRosterDay :: (?context :: ControllerContext) => [SlotName] -> [Staff] -> Day -> [RosterSlot] -> [(Id RosterSlot, [RosterConflict])] -> RosterDay -> Html
renderRosterDay slotNames staffMembers weekStartDate allSlots slotConflicts rosterDay = [hsx|
    {renderDayRows slotNames staffMembers (Calendar.addDays (toInteger (get #dayOffset rosterDay)) weekStartDate) rosterDay daySlots slotConflicts}
|]
    where
        daySlots = filter (\s -> s.rosterDayId == coerce rosterDay.id) allSlots

rowsForDay :: [RosterSlot] -> [(Int, [RosterSlot])]
rowsForDay slots =
    case (slots |> map (.rowIndex) |> nub |> sort) of
        [] -> [(-1, [])]
        indices -> map (\rowIndex -> (rowIndex, filter (\slot -> slot.rowIndex == rowIndex) slots)) indices

renderDayRows :: (?context :: ControllerContext) => [SlotName] -> [Staff] -> Day -> RosterDay -> [RosterSlot] -> [(Id RosterSlot, [RosterConflict])] -> Html
renderDayRows slotNames staffMembers date rosterDay slots slotConflicts = [hsx|
    {forEach indexedRows (renderRow slotNames staffMembers date rosterDay rowCount slotConflicts)}
|]
    where
        dayRows = rowsForDay slots
        rowCount = length dayRows
        indexedRows = zip [0 :: Int ..] dayRows

renderRow :: (?context :: ControllerContext) => [SlotName] -> [Staff] -> Day -> RosterDay -> Int -> [(Id RosterSlot, [RosterConflict])] -> (Int, (Int, [RosterSlot])) -> Html
renderRow slotNames staffMembers date rosterDay rowCount slotConflicts rowData =
    renderRowWithAttrs slotNames staffMembers date rosterDay rowCount slotConflicts rowData Nothing

renderRowOob :: (?context :: ControllerContext) => [SlotName] -> [Staff] -> Day -> RosterDay -> Int -> [(Id RosterSlot, [RosterConflict])] -> (Int, (Int, [RosterSlot])) -> Html
renderRowOob slotNames staffMembers date rosterDay rowCount slotConflicts rowData =
    renderRowWithAttrs slotNames staffMembers date rosterDay rowCount slotConflicts rowData (Just "outerHTML")

renderRowWithAttrs :: (?context :: ControllerContext) => [SlotName] -> [Staff] -> Day -> RosterDay -> Int -> [(Id RosterSlot, [RosterConflict])] -> (Int, (Int, [RosterSlot])) -> Maybe Text -> Html
renderRowWithAttrs slotNames staffMembers date rosterDay rowCount slotConflicts (rowPosition, (rowIndex, rowSlots)) maybeSwapOob = [hsx|
    <tr id={rosterRowDomIdText rosterDay.id rowIndex}
        data-roster-row="true"
        hx-swap-oob={maybeSwapOob}
        class={classes [("day-row", True), ("day-row-" <> tshow (get #dayOffset rosterDay), True), ("day-alt-dark", odd (get #dayOffset rosterDay)), ("day-alt-light", even (get #dayOffset rosterDay))]}>
        {when (rowPosition == 0) (renderDayLabel date rosterDay rowCount)}
        {forEach (zip [0 :: Int ..] slotNames) (renderBlockCells staffMembers rosterDay.id rowIndex rowSlots slotConflicts)}
    </tr>
|]

rosterRowDomIdText :: Id RosterDay -> Int -> Text
rosterRowDomIdText rosterDayId rowIndex = "roster-row-" <> tshow rosterDayId <> "-" <> tshow rowIndex

renderDayLabel :: (?context :: ControllerContext) => Day -> RosterDay -> Int -> Html
renderDayLabel date rosterDay rowCount = [hsx|
    <td class="fw-bold day-label p-2" rowspan={tshow rowCount}>
        <div class="d-flex flex-column gap-2">
            <div class="roster-day-heading">
                <div class="small app-muted">{Text.pack (formatTime defaultTimeLocale "%a" date)}</div>
                <div>{Text.pack (formatTime defaultTimeLocale "%d/%m" date)}</div>
            </div>
            {renderAddRowButton rosterDay}
        </div>
    </td>
|]

renderAddRowButton :: (?context :: ControllerContext) => RosterDay -> Html
renderAddRowButton rosterDay =
    if currentUserIsManager
        then [hsx|
            <button class="btn btn-link btn-sm p-0 text-decoration-none roster-day-control"
                    hx-post={AddRosterRowAction rosterDay.id}
                    hx-target="#roster-content"
                    hx-swap="outerHTML"
                    title="Add shift row">
                [+]
            </button>
        |]
        else [hsx|<span></span>|]

renderDeleteRowButton :: (?context :: ControllerContext) => Id RosterDay -> Int -> Html
renderDeleteRowButton _ rowIndex | rowIndex < 0 = [hsx|<span></span>|]
renderDeleteRowButton rosterDayId rowIndex =
    if currentUserIsManager
        then [hsx|
            <button class="btn btn-link btn-sm p-0 text-danger text-decoration-none roster-day-control"
                    hx-post={DeleteRosterRowAction rosterDayId rowIndex}
                    hx-confirm="Delete this entire shift row?"
                    hx-target="#roster-content"
                    hx-swap="outerHTML"
                    title="Delete row">
                [-]
            </button>
        |]
        else [hsx|<span></span>|]

renderBlockCells :: (?context :: ControllerContext) => [Staff] -> Id RosterDay -> Int -> [RosterSlot] -> [(Id RosterSlot, [RosterConflict])] -> (Int, SlotName) -> Html
renderBlockCells staffMembers rosterDayId rowIndex rowSlots slotConflicts (blockIndex, slotName) =
    case find (\slot -> slot.slotNameId == coerce slotName.id) rowSlots of
        Just slot ->
            let currentStartTime = optionalTimeOfDayToStorageValue slot.startTime
                currentStartTimeLabel = if Text.null currentStartTime then "Select time" else storageTimeToDisplayLabel currentStartTime
                currentNote = fromMaybe "" slot.note
                currentConflicts = lookupConflicts slot.id slotConflicts
             in [hsx|
                <td class={classes [("slot-time-cell", True), ("roster-block-start", blockIndex > 0)]}>
                    <form class="m-0 d-flex align-items-center gap-1 slot-cell-form" data-time-picker-field="true">
                        <input type="hidden"
                               name="startTime"
                               value={currentStartTime}
                               class="slot-time-input slot-cell-input js-time-picker-input"
                               hx-post={UpdateRosterSlotAction slot.id}
                               hx-trigger="change"
                               hx-include="closest form"
                               hx-sync="#roster-content:queue last"
                               hx-swap="none"
                               disabled={not currentUserIsManager} />
                        <button type="button"
                                class="btn btn-sm slot-time-trigger js-time-picker-trigger"
                                disabled={not currentUserIsManager}>
                            <span class={classes [("js-time-picker-label", True), ("app-muted", Text.null currentStartTime)]}>{currentStartTimeLabel}</span>
                        </button>
                        {when (blockIndex == 0) (renderDeleteRowButton rosterDayId rowIndex)}
                    </form>
                </td>

                <td class={classes [("slot-staff-cell position-relative", True), (renderConflictClass currentConflicts, True)]}>
                    <form class="m-0 slot-cell-form">
                        <select name="staffId"
                                class="form-select form-select-sm slot-cell-input slot-staff-input"
                                hx-post={UpdateRosterSlotAction slot.id}
                                hx-trigger="change"
                                hx-include="closest form"
                                hx-sync="#roster-content:queue last"
                                hx-swap="none"
                                disabled={not currentUserIsManager}>
                            <option value="">Unassigned</option>
                            {forEach staffMembers (renderStaffOption slot.staffId)}
                        </select>
                        {renderConflictBadge currentConflicts}
                    </form>
                </td>

                <td class="slot-note-cell roster-block-end">
                    <form class="m-0 slot-cell-form">
                        <input type="text"
                               name="note"
                               value={currentNote}
                               placeholder="Code"
                               class="form-control form-control-sm slot-note-input slot-cell-input"
                               hx-post={UpdateRosterSlotAction slot.id}
                               hx-trigger="change"
                               hx-include="closest form"
                               hx-sync="#roster-content:queue last"
                               hx-swap="none"
                               disabled={not currentUserIsManager} />
                    </form>
                </td>
            |]
        Nothing ->
            mconcat
                [ [hsx|<td class={classes [("slot-empty-cell", True), ("roster-block-start", blockIndex > 0)]}></td>|]
                , [hsx|<td class="slot-empty-cell"></td>|]
                , [hsx|<td class="slot-empty-cell roster-block-end"></td>|]
                ]

renderStaffOption :: Maybe UUID -> Staff -> Html
renderStaffOption selectedStaffId staff = [hsx|
    <option value={tshow staff.id} selected={Just (coerce staff.id) == selectedStaffId}>
        {staff.lastName}, {staff.firstName}
    </option>
|]

lookupConflicts :: Id RosterSlot -> [(Id RosterSlot, [RosterConflict])] -> [RosterConflict]
lookupConflicts slotId slotConflicts = fromMaybe [] (lookup slotId slotConflicts)

renderConflictClass :: [RosterConflict] -> Text
renderConflictClass [] = ""
renderConflictClass (conflict:_) =
    case conflict.severity of
        CriticalConflict -> "conflict-critical"
        AdvisoryConflict -> "conflict-advisory"

renderConflictBadge :: [RosterConflict] -> Html
renderConflictBadge [] = [hsx|<span></span>|]
renderConflictBadge (conflict:_) = [hsx|
    <span class={classes [("badge", True), ("position-absolute", True), ("top-0", True), ("end-0", True), ("translate-middle", True), ("bg-danger", conflict.severity == CriticalConflict), ("bg-warning text-dark", conflict.severity == AdvisoryConflict)]}
          title={conflict.message}>
        !
    </span>
|]

renderStatusBadge :: Bool -> Html
renderStatusBadge isLive =
    if isLive
        then [hsx|<span class="badge bg-success shadow-sm px-3 py-2">Live / Published</span>|]
        else [hsx|<span class="badge bg-warning text-dark shadow-sm px-3 py-2">Draft Mode</span>|]

renderCreateForm :: Int -> Html
renderCreateForm weekOffset = [hsx|
    <div class="d-flex gap-2">
        <form method="POST" action={CopyRosterWeekAction (weekOffset - 1) weekOffset}>
            <button type="submit" class="btn btn-outline-primary px-4 py-2">Copy Previous Week</button>
        </form>
        <form method="POST" action={CreateRosterWeekAction weekOffset}>
            <button type="submit" class="btn btn-primary px-4 py-2">Create Draft Roster</button>
        </form>
    </div>
|]

renderPublishForm :: RosterWeek -> Html
renderPublishForm rosterWeek = [hsx|
    <form method="POST" action={PublishRosterWeekAction rosterWeek.id} class="d-inline">
        <button type="submit" class="btn btn-success px-4 py-2 fw-bold">Publish Week</button>
    </form>
|]
