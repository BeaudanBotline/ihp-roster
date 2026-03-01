module Web.View.Timesheets.Index where

import Web.View.Prelude

data IndexView = IndexView

instance View IndexView where
    html IndexView = [hsx|
        <div class="app-panel app-form-width">
            <div class="app-panel-body">
                <h1 class="h4 mb-3">Timesheets</h1>
                <p class="app-muted mb-0">Timesheets is coming soon.</p>
            </div>
        </div>
    |]
