module Web.View.Sessions.New where
import Web.View.Prelude
import IHP.AuthSupport.View.Sessions.New

instance View (NewView User) where
    html NewView { .. } = [hsx|
        <div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
            <div class="card shadow-sm" style="width: 100%; max-width: 420px;">
                <div class="card-body p-4">
                    <h4 class="card-title mb-4 text-center">Sign In</h4>
                    {renderForm user}
                    <hr/>
                    <p class="text-center mb-0 text-muted small">
                        Don't have an account?
                        <a href={NewUserAction}>Create one</a>
                    </p>
                </div>
            </div>
        </div>
    |]

renderForm :: User -> Html
renderForm user = [hsx|
    <form method="POST" action={CreateSessionAction}>
        <div class="mb-3">
            <label class="form-label" for="email">Email address</label>
            <input
                id="email"
                name="email"
                value={user.email}
                type="email"
                class="form-control"
                placeholder="you@example.com"
                required="required"
                autofocus="autofocus"
            />
        </div>
        <div class="mb-3">
            <label class="form-label" for="password">Password</label>
            <input
                id="password"
                name="password"
                type="password"
                class="form-control"
                placeholder="••••••••"
                required="required"
            />
        </div>
        <div class="d-grid mt-4">
            <button type="submit" class="btn btn-primary">Sign In</button>
        </div>
    </form>
|]
