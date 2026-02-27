module Web.View.Profiles.Edit where

import Web.View.Prelude

newtype EditView = EditView { staff :: Staff }

instance View EditView where
    html EditView { .. } = [hsx|
        <div class="min-vh-100 d-flex align-items-center justify-content-center bg-light">
            <div class="card shadow-sm" style="width: 100%; max-width: 480px;">
                <div class="card-body p-4">
                    <h4 class="card-title mb-3 text-center">Complete Your Profile</h4>
                    <p class="text-muted text-center">Add your name to continue.</p>
                    {renderForm staff}
                </div>
            </div>
        </div>
    |]

renderForm :: Staff -> Html
renderForm staff = [hsx|
    <form method="POST" action={UpdateProfileAction}>
        <div class="mb-3">
            <label for="firstName" class="form-label">First Name</label>
            <input
                id="firstName"
                name="firstName"
                type="text"
                class="form-control"
                value={staff.firstName}
                required="required"
                autofocus="autofocus"
            />
        </div>
        <div class="mb-3">
            <label for="lastName" class="form-label">Last Name</label>
            <input
                id="lastName"
                name="lastName"
                type="text"
                class="form-control"
                value={staff.lastName}
                required="required"
            />
        </div>
        <div class="d-grid mt-4">
            <button type="submit" class="btn btn-primary">Save and Continue</button>
        </div>
    </form>
|]
