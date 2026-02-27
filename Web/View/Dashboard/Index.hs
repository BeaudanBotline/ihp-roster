module Web.View.Dashboard.Index where
import Web.View.Prelude

data IndexView = IndexView

instance View IndexView where
    html IndexView = [hsx|
        <div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
            <div class="text-center">
                <p class="text-muted mb-4">Logged in as <strong>{currentUser.email}</strong></p>
                {when currentUserIsManager managerLinks}
                <a class="btn btn-outline-danger js-delete js-delete-no-confirm" href={DeleteSessionAction}>
                    Logout
                </a>
            </div>
        </div>
    |]

managerLinks :: Html
managerLinks = [hsx|
    <div class="mb-3">
        <a href={StaffAction} class="btn btn-outline-primary">Manage Staff</a>
    </div>
|]
