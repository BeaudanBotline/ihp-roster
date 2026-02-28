module Web.View.Dashboard.Index where
import Web.View.Prelude

data IndexView = IndexView

instance View IndexView where
    html IndexView = [hsx|
        <div class="app-page-auth">
            <div class="app-panel app-form-width text-center">
                <div class="app-panel-body">
                    <p class="app-muted mb-4">Logged in as <strong>{currentUser.email}</strong></p>
                    {when currentUserIsManager managerLinks}
                    <a class="btn btn-outline-danger js-delete js-delete-no-confirm" href={DeleteSessionAction}>
                        Logout
                    </a>
                </div>
            </div>
        </div>
    |]

managerLinks :: Html
managerLinks = [hsx|
    <div class="mb-3">
        <a href={StaffAction} class="btn btn-outline-primary">Manage Staff</a>
    </div>
|]
