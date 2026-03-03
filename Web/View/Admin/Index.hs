module Web.View.Admin.Index where

import Web.View.Prelude

data IndexView = IndexView

instance View IndexView where
    html IndexView = [hsx|
        <div class="row g-3">
            <div class="col-12 col-lg-7">
                <div class="app-panel h-100">
                    <div class="app-panel-body">
                        <h1 class="h4 mb-3">Admin</h1>
                        <p class="app-muted mb-0">
                            Venue administration is still narrow by design. Use exports for controlled payroll-adjacent disclosures.
                        </p>
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
        </div>
    |]
