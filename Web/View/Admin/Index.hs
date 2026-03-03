module Web.View.Admin.Index where

import Data.Time.Format (defaultTimeLocale, formatTime)
import Web.View.Prelude

data IndexView = IndexView
    { latestSnapshot  :: Maybe PayConfigSnapshot
    , recentSnapshots :: [PayConfigSnapshot]
    , payLevels       :: [PayLevel]
    , shiftTypes      :: [ShiftType]
    , slotNames       :: [SlotName]
    , dayNames        :: [DayName]
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <div class="row g-3">
            <div class="col-12 col-xl-8">
                <div class="app-panel mb-3">
                    <div class="app-panel-body">
                        <h1 class="h4 mb-2">Admin</h1>
                        <p class="app-muted mb-0">
                            Manage venue-owned config tables here, then save a pay/config snapshot when you want a historical version for approvals and exports.
                        </p>
                    </div>
                </div>
                <div class="row g-3">
                    <div class="col-12 col-lg-6">
                        {renderPayLevelsSection payLevels}
                    </div>
                    <div class="col-12 col-lg-6">
                        {renderShiftTypesSection shiftTypes payLevels}
                    </div>
                    <div class="col-12 col-lg-6">
                        {renderSlotNamesSection slotNames}
                    </div>
                    <div class="col-12 col-lg-6">
                        {renderDayNamesSection dayNames}
                    </div>
                </div>
            </div>
            <div class="col-12 col-xl-4">
                <div class="app-panel mb-3">
                    <div class="app-panel-body">
                        <h2 class="h5 mb-2">Pay/Config Snapshots</h2>
                        <p class="app-muted mb-3">
                            Save immutable versions before or between payroll-adjacent approval cycles so historical outputs stay explainable.
                        </p>
                        {renderSnapshotSummary latestSnapshot}
                        <form method="POST" action={CreatePayConfigSnapshotAction} class="mt-3">
                            <button class="btn btn-primary" type="submit">Save Snapshot</button>
                        </form>
                    </div>
                </div>
                <div class="app-panel">
                    <div class="app-panel-body">
                        <h2 class="h5 mb-2">Exports</h2>
                        <p class="app-muted mb-3">
                            Generate approved-timesheet CSV exports with explicit scope, expiry, and audit logging.
                        </p>
                        <a href={ExportJobsAction} class="btn btn-primary">Manage Exports</a>
                    </div>
                </div>
            </div>
            <div class="col-12">
                <div class="app-panel">
                    <div class="app-panel-body">
                        <h2 class="h5 mb-3">Recent Versions</h2>
                        {renderSnapshotTable recentSnapshots}
                    </div>
                </div>
            </div>
        </div>
    |]

renderPayLevelsSection :: [PayLevel] -> Html
renderPayLevelsSection payLevels =
    renderConfigSection
        "Pay Levels"
        "Configure venue pay level names and whether they remain selectable."
        (renderPayLevelCreateForm)
        (if null payLevels then renderEmptyState "No pay levels yet." else forEach payLevels renderPayLevelRow)

renderShiftTypesSection :: [ShiftType] -> [PayLevel] -> Html
renderShiftTypesSection shiftTypes payLevels =
    renderConfigSection
        "Shift Types"
        "Each shift type points to a default pay level used by pay resolution."
        (renderShiftTypeCreateForm payLevels)
        (if null shiftTypes then renderEmptyState "No shift types yet." else forEach shiftTypes (renderShiftTypeRow payLevels))

renderSlotNamesSection :: [SlotName] -> Html
renderSlotNamesSection slotNames =
    renderConfigSection
        "Slot Names"
        "These power the roster sheet block labels and remain venue-scoped."
        renderSlotNameCreateForm
        (if null slotNames then renderEmptyState "No slot names yet." else forEach slotNames renderSlotNameRow)

renderDayNamesSection :: [DayName] -> Html
renderDayNamesSection dayNames =
    renderConfigSection
        "Day Names"
        "Weekday labels can be customised per venue and toggled active/inactive."
        renderDayNameCreateForm
        (if null dayNames then renderEmptyState "No day names yet." else forEach dayNames renderDayNameRow)

renderConfigSection :: Text -> Text -> Html -> Html -> Html
renderConfigSection title description createForm rows = [hsx|
    <div class="app-panel h-100">
        <div class="app-panel-body">
            <h2 class="h5 mb-2">{title}</h2>
            <p class="app-muted mb-3">{description}</p>
            {createForm}
            <div class="mt-3">
                {rows}
            </div>
        </div>
    </div>
|]

renderPayLevelCreateForm :: Html
renderPayLevelCreateForm = [hsx|
    <form method="POST" action={CreatePayLevelAction} class="border rounded p-3">
        <div class="row g-2 align-items-end">
            <div class="col-12 col-md-6">
                <label class="form-label" for="new-pay-level-name">Name</label>
                <input id="new-pay-level-name" class="form-control" type="text" name="name" placeholder="Level 1" />
            </div>
            <div class="col-12 col-md-3">
                <label class="form-label" for="new-pay-level-active">Status</label>
                <select id="new-pay-level-active" class="form-select" name="isActive">
                    <option value="true" selected={True}>Active</option>
                    <option value="false">Inactive</option>
                </select>
            </div>
            <div class="col-12 col-md-3">
                <button class="btn btn-outline-primary w-100" type="submit">Add Pay Level</button>
            </div>
        </div>
    </form>
|]

renderPayLevelRow :: PayLevel -> Html
renderPayLevelRow payLevel = [hsx|
    <form method="POST" action={UpdatePayLevelAction (get #id payLevel)} class="border rounded p-3 mb-2">
        <div class="d-flex justify-content-between align-items-center mb-2">
            <span class="fw-semibold">Pay Level</span>
            {renderActiveBadge payLevel.isActive}
        </div>
        <div class="row g-2 align-items-end">
            <div class="col-12 col-md-6">
                <label class="form-label">Name</label>
                <input class="form-control" type="text" name="name" value={payLevel.name} />
            </div>
            <div class="col-12 col-md-3">
                <label class="form-label">Status</label>
                <select class="form-select" name="isActive">
                    <option value="true" selected={payLevel.isActive}>Active</option>
                    <option value="false" selected={not payLevel.isActive}>Inactive</option>
                </select>
            </div>
            <div class="col-12 col-md-3">
                <button class="btn btn-outline-secondary w-100" type="submit">Update</button>
            </div>
        </div>
    </form>
|]

renderShiftTypeCreateForm :: [PayLevel] -> Html
renderShiftTypeCreateForm payLevels
    | null payLevels = [hsx|
        <div class="alert alert-warning mb-0">
            Add a pay level before creating shift types.
        </div>
    |]
    | otherwise = [hsx|
        <form method="POST" action={CreateShiftTypeAction} class="border rounded p-3">
            <div class="row g-2 align-items-end">
                <div class="col-12 col-md-4">
                    <label class="form-label" for="new-shift-type-name">Name</label>
                    <input id="new-shift-type-name" class="form-control" type="text" name="name" placeholder="Standard Shift" />
                </div>
                <div class="col-12 col-md-4">
                    <label class="form-label" for="new-shift-type-pay-level">Default Pay Level</label>
                    <select id="new-shift-type-pay-level" class="form-select" name="defaultPayLevelId">
                        {forEach payLevels renderPayLevelOption}
                    </select>
                </div>
                <div class="col-12 col-md-2">
                    <label class="form-label" for="new-shift-type-active">Status</label>
                    <select id="new-shift-type-active" class="form-select" name="isActive">
                        <option value="true" selected={True}>Active</option>
                        <option value="false">Inactive</option>
                    </select>
                </div>
                <div class="col-12 col-md-2">
                    <button class="btn btn-outline-primary w-100" type="submit">Add</button>
                </div>
            </div>
        </form>
    |]

renderShiftTypeRow :: [PayLevel] -> ShiftType -> Html
renderShiftTypeRow payLevels shiftType = [hsx|
    <form method="POST" action={UpdateShiftTypeAction (get #id shiftType)} class="border rounded p-3 mb-2">
        <div class="d-flex justify-content-between align-items-center mb-2">
            <span class="fw-semibold">Shift Type</span>
            {renderActiveBadge shiftType.isActive}
        </div>
        <div class="row g-2 align-items-end">
            <div class="col-12 col-md-4">
                <label class="form-label">Name</label>
                <input class="form-control" type="text" name="name" value={shiftType.name} />
            </div>
            <div class="col-12 col-md-4">
                <label class="form-label">Default Pay Level</label>
                <select class="form-select" name="defaultPayLevelId">
                    {forEach payLevels (renderSelectedPayLevelOption shiftType.defaultPayLevelId)}
                </select>
            </div>
            <div class="col-12 col-md-2">
                <label class="form-label">Status</label>
                <select class="form-select" name="isActive">
                    <option value="true" selected={shiftType.isActive}>Active</option>
                    <option value="false" selected={not shiftType.isActive}>Inactive</option>
                </select>
            </div>
            <div class="col-12 col-md-2">
                <button class="btn btn-outline-secondary w-100" type="submit">Update</button>
            </div>
        </div>
    </form>
|]

renderSlotNameCreateForm :: Html
renderSlotNameCreateForm = [hsx|
    <form method="POST" action={CreateSlotNameAction} class="border rounded p-3">
        <div class="row g-2 align-items-end">
            <div class="col-12 col-md-6">
                <label class="form-label" for="new-slot-name">Name</label>
                <input id="new-slot-name" class="form-control" type="text" name="name" placeholder="Early" />
            </div>
            <div class="col-12 col-md-3">
                <label class="form-label" for="new-slot-active">Status</label>
                <select id="new-slot-active" class="form-select" name="isActive">
                    <option value="true" selected={True}>Active</option>
                    <option value="false">Inactive</option>
                </select>
            </div>
            <div class="col-12 col-md-3">
                <button class="btn btn-outline-primary w-100" type="submit">Add Slot</button>
            </div>
        </div>
    </form>
|]

renderSlotNameRow :: SlotName -> Html
renderSlotNameRow slotName = [hsx|
    <form method="POST" action={UpdateSlotNameAction (get #id slotName)} class="border rounded p-3 mb-2">
        <div class="d-flex justify-content-between align-items-center mb-2">
            <span class="fw-semibold">Slot Name</span>
            {renderActiveBadge slotName.isActive}
        </div>
        <div class="row g-2 align-items-end">
            <div class="col-12 col-md-6">
                <label class="form-label">Name</label>
                <input class="form-control" type="text" name="name" value={slotName.name} />
            </div>
            <div class="col-12 col-md-3">
                <label class="form-label">Status</label>
                <select class="form-select" name="isActive">
                    <option value="true" selected={slotName.isActive}>Active</option>
                    <option value="false" selected={not slotName.isActive}>Inactive</option>
                </select>
            </div>
            <div class="col-12 col-md-3">
                <button class="btn btn-outline-secondary w-100" type="submit">Update</button>
            </div>
        </div>
    </form>
|]

renderDayNameCreateForm :: Html
renderDayNameCreateForm = [hsx|
    <form method="POST" action={CreateDayNameAction} class="border rounded p-3">
        <div class="row g-2 align-items-end">
            <div class="col-12 col-md-4">
                <label class="form-label" for="new-day-weekday">Weekday</label>
                <select id="new-day-weekday" class="form-select" name="weekdayIndex">
                    {forEach weekdayOptions renderWeekdayOption}
                </select>
            </div>
            <div class="col-12 col-md-4">
                <label class="form-label" for="new-day-name">Name</label>
                <input id="new-day-name" class="form-control" type="text" name="name" placeholder="Monday" />
            </div>
            <div class="col-12 col-md-2">
                <label class="form-label" for="new-day-active">Status</label>
                <select id="new-day-active" class="form-select" name="isActive">
                    <option value="true" selected={True}>Active</option>
                    <option value="false">Inactive</option>
                </select>
            </div>
            <div class="col-12 col-md-2">
                <button class="btn btn-outline-primary w-100" type="submit">Add</button>
            </div>
        </div>
    </form>
|]

renderDayNameRow :: DayName -> Html
renderDayNameRow dayName = [hsx|
    <form method="POST" action={UpdateDayNameAction (get #id dayName)} class="border rounded p-3 mb-2">
        <div class="d-flex justify-content-between align-items-center mb-2">
            <span class="fw-semibold">Day Name</span>
            {renderActiveBadge dayName.isActive}
        </div>
        <div class="row g-2 align-items-end">
            <div class="col-12 col-md-4">
                <label class="form-label">Weekday</label>
                <select class="form-select" name="weekdayIndex">
                    {forEach weekdayOptions (renderSelectedWeekdayOption dayName.weekdayIndex)}
                </select>
            </div>
            <div class="col-12 col-md-4">
                <label class="form-label">Name</label>
                <input class="form-control" type="text" name="name" value={dayName.name} />
            </div>
            <div class="col-12 col-md-2">
                <label class="form-label">Status</label>
                <select class="form-select" name="isActive">
                    <option value="true" selected={dayName.isActive}>Active</option>
                    <option value="false" selected={not dayName.isActive}>Inactive</option>
                </select>
            </div>
            <div class="col-12 col-md-2">
                <button class="btn btn-outline-secondary w-100" type="submit">Update</button>
            </div>
        </div>
    </form>
|]

renderSnapshotSummary :: Maybe PayConfigSnapshot -> Html
renderSnapshotSummary maybeSnapshot =
    case maybeSnapshot of
        Nothing -> [hsx|
            <div class="alert alert-warning mb-0">
                No pay/config snapshot has been saved yet. The first snapshot will be created from the venue's current config tables.
            </div>
        |]
        Just snapshot -> [hsx|
            <div class="border rounded p-3">
                <div class="fw-semibold">Active snapshot: {snapshot.versionLabel}</div>
                <div class="small app-muted">Saved {formatTimestamp snapshot.createdAt}</div>
            </div>
        |]

renderSnapshotTable :: [PayConfigSnapshot] -> Html
renderSnapshotTable snapshots
    | null snapshots = [hsx|<p class="app-muted mb-0">No saved versions yet.</p>|]
    | otherwise = [hsx|
        <div class="table-responsive">
            <table class="table table-striped align-middle mb-0">
                <thead>
                    <tr>
                        <th>Version</th>
                        <th>Saved At</th>
                    </tr>
                </thead>
                <tbody>
                    {forEach snapshots renderSnapshotRow}
                </tbody>
            </table>
        </div>
    |]

renderSnapshotRow :: PayConfigSnapshot -> Html
renderSnapshotRow snapshot = [hsx|
    <tr>
        <td>{snapshot.versionLabel}</td>
        <td>{formatTimestamp snapshot.createdAt}</td>
    </tr>
|]

renderPayLevelOption :: PayLevel -> Html
renderPayLevelOption payLevel = [hsx|
    <option value={tshow (unpackId (get #id payLevel))}>{renderPayLevelLabel payLevel}</option>
|]

renderSelectedPayLevelOption :: UUID -> PayLevel -> Html
renderSelectedPayLevelOption selectedPayLevelId payLevel = [hsx|
    <option value={tshow (unpackId (get #id payLevel))} selected={unpackId (get #id payLevel) == selectedPayLevelId}>{renderPayLevelLabel payLevel}</option>
|]

renderWeekdayOption :: (Int, Text) -> Html
renderWeekdayOption (weekdayIndex, label) = [hsx|
    <option value={tshow weekdayIndex}>{label}</option>
|]

renderSelectedWeekdayOption :: Int -> (Int, Text) -> Html
renderSelectedWeekdayOption selectedWeekdayIndex (weekdayIndex, label) = [hsx|
    <option value={tshow weekdayIndex} selected={weekdayIndex == selectedWeekdayIndex}>{label}</option>
|]

renderPayLevelLabel :: PayLevel -> Text
renderPayLevelLabel payLevel =
    if payLevel.isActive
        then payLevel.name
        else payLevel.name <> " (inactive)"

renderActiveBadge :: Bool -> Html
renderActiveBadge isActive =
    if isActive
        then [hsx|<span class="badge text-bg-success">active</span>|]
        else [hsx|<span class="badge text-bg-secondary">inactive</span>|]

renderEmptyState :: Text -> Html
renderEmptyState message = [hsx|<p class="app-muted mb-0">{message}</p>|]

weekdayOptions :: [(Int, Text)]
weekdayOptions =
    [ (0, "Sunday")
    , (1, "Monday")
    , (2, "Tuesday")
    , (3, "Wednesday")
    , (4, "Thursday")
    , (5, "Friday")
    , (6, "Saturday")
    ]

formatTimestamp :: UTCTime -> Text
formatTimestamp = cs . formatTime defaultTimeLocale "%Y-%m-%d %H:%M UTC"
