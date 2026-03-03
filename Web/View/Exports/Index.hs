module Web.View.Exports.Index where

import Application.Helper.Export
import qualified Data.Text as Text
import Data.Time.Format (defaultTimeLocale, formatTime)
import Web.View.Prelude

data IndexView = IndexView
    { exportJobs        :: [ExportJob]
    , defaultRangeStart :: Day
    , defaultRangeEnd   :: Day
    }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <div class="row g-3">
            <div class="col-12 col-xl-5">
                <div class="app-panel h-100">
                    <div class="app-panel-body">
                        <h1 class="h4 mb-3">Export Jobs</h1>
                        <p class="app-muted mb-4">
                            Generate a venue-scoped CSV of approved timesheets. Downloads use per-job expiring tokens and are audited.
                        </p>
                        <form method="POST" action={CreateExportJobAction} class="d-grid gap-3">
                            <div>
                                <label class="form-label" for="rangeStart">From</label>
                                <input
                                    id="rangeStart"
                                    class="form-control"
                                    type="date"
                                    name="rangeStart"
                                    value={tshow defaultRangeStart}
                                    required={True}
                                />
                            </div>
                            <div>
                                <label class="form-label" for="rangeEnd">To</label>
                                <input
                                    id="rangeEnd"
                                    class="form-control"
                                    type="date"
                                    name="rangeEnd"
                                    value={tshow defaultRangeEnd}
                                    required={True}
                                />
                            </div>
                            <div class="small app-muted">
                                Export type: approved timesheets CSV. Scope is always limited to the current venue and the selected date range.
                            </div>
                            <button class="btn btn-primary" type="submit">Generate Export</button>
                        </form>
                    </div>
                </div>
            </div>
            <div class="col-12 col-xl-7">
                <div class="app-panel h-100">
                    <div class="app-panel-body">
                        <div class="d-flex justify-content-between align-items-start gap-3 mb-3">
                            <div>
                                <h2 class="h5 mb-1">Recent Exports</h2>
                                <p class="app-muted mb-0">Most recent export jobs for this venue.</p>
                            </div>
                            <a href={AdminAction} class="btn btn-outline-secondary btn-sm">Back to admin</a>
                        </div>
                        {if null exportJobs then renderEmptyState else renderExportTable exportJobs}
                    </div>
                </div>
            </div>
        </div>
    |]

renderEmptyState :: Html
renderEmptyState = [hsx|
    <div class="app-muted mb-0">No export jobs yet.</div>
|]

renderExportTable :: [ExportJob] -> Html
renderExportTable exportJobs = [hsx|
    <div class="table-responsive">
        <table class="table table-sm align-middle mb-0">
            <thead>
                <tr>
                    <th>Created</th>
                    <th>Range</th>
                    <th>Status</th>
                    <th>Expires</th>
                    <th class="text-end">Action</th>
                </tr>
            </thead>
            <tbody>
                {forEach exportJobs renderExportJobRow}
            </tbody>
        </table>
    </div>
|]

renderExportJobRow :: ExportJob -> Html
renderExportJobRow exportJob = [hsx|
    <tr>
        <td>{formatTimestamp exportJob.createdAt}</td>
        <td>{renderRange exportJob}</td>
        <td>{renderStatusBadge exportJob}</td>
        <td>{formatTimestamp exportJob.expiresAt}</td>
        <td class="text-end">{renderDownloadAction exportJob}</td>
    </tr>
|]

renderRange :: ExportJob -> Html
renderRange exportJob =
    case (exportJob.rangeStart, exportJob.rangeEnd) of
        (Just rangeStart, Just rangeEnd) -> [hsx|{tshow rangeStart} to {tshow rangeEnd}|]
        _ -> [hsx|<span class="app-muted">Unscoped</span>|]

renderStatusBadge :: ExportJob -> Html
renderStatusBadge exportJob =
    case parseExportJobStatus exportJob.status of
        Just ExportReady -> [hsx|<span class="badge bg-success-subtle text-success-emphasis">ready</span>|]
        Just ExportExpired -> [hsx|<span class="badge bg-secondary">expired</span>|]
        _ -> [hsx|<span class="badge bg-warning-subtle text-warning-emphasis">pending</span>|]

renderDownloadAction :: ExportJob -> Html
renderDownloadAction exportJob =
    case (parseExportJobStatus exportJob.status, exportJob.fileName) of
        (Just ExportReady, Just _) ->
            let downloadUrl = appendQueryParams (pathTo (DownloadExportJobAction (get #id exportJob))) [("token", tshow exportJob.downloadToken)]
             in [hsx|
                    <a href={downloadUrl} class="btn btn-outline-primary btn-sm">Download</a>
                |]
        _ -> [hsx|<span class="app-muted small">Unavailable</span>|]

formatTimestamp :: UTCTime -> Text
formatTimestamp timestamp = Text.pack (formatTime defaultTimeLocale "%Y-%m-%d %H:%M UTC" timestamp)
