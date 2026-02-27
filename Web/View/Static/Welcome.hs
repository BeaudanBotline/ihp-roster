module Web.View.Static.Welcome where
import Web.View.Prelude

data WelcomeView = WelcomeView

instance View WelcomeView where
    html WelcomeView = [hsx|
        <div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
            <div class="text-center p-4" style="max-width: 480px; width: 100%;">
                <h1 class="display-5 fw-bold mb-2">Welcome</h1>
                <p class="text-muted mb-5">Sign in to your account or create a new one to get started.</p>
                <div class="d-grid gap-3">
                    <a href={NewSessionAction} class="btn btn-primary btn-lg">Sign In</a>
                    <a href={NewUserAction} class="btn btn-outline-secondary btn-lg">Create Account</a>
                </div>
            </div>
        </div>
    |]
