module Web.View.Admin.Index where

import Data.Time.Format (defaultTimeLocale, formatTime)
import Web.View.Prelude

data IndexView = IndexView
    { latestSnapshot  :: Maybe PayConfigSnapshot
    , recentSnapshots :: [PayConfigSnapshot]
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <div class="row g-3">
            <div class="col-12 col-lg-7">
                <div class="app-panel h-100">
                    <div class="app-panel-body">
                        <h1 class="h4 mb-3">Admin</h1>
                        <p class="app-muted mb-3">
                            Save immutable pay/config snapshots before or between payroll-adjacent approval cycles so historical outputs stay explainable.
                        </p>
                        {renderSnapshotSummary latestSnapshot}
                        <form method="POST" action={CreatePayConfigSnapshotAction} class="mt-3">
                            <button class="btn btn-primary" type="submit">Save Snapshot</button>
                        </form>
                    </div>
                </div>
            </div>
            <div class="col-12 col-lg-5">
                <div class="app-panel h-100">
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

formatTimestamp :: UTCTime -> Text
formatTimestamp = cs . formatTime defaultTimeLocale "%Y-%m-%d %H:%M UTC"
