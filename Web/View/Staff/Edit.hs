module Web.View.Staff.Edit where

import Web.View.Prelude

newtype EditView = EditView { staff :: Staff }

instance View EditView where
    html EditView { .. } = [hsx|
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href={DashboardAction}>Dashboard</a></li>
                <li class="breadcrumb-item"><a href={StaffAction}>Staff</a></li>
                <li class="breadcrumb-item active">Edit</li>
            </ol>
        </nav>

        <h1>Edit Staff Member</h1>
        {renderForm staff (UpdateStaffAction staff.id)}
    |]

renderForm :: Staff -> StaffController -> Html
renderForm staff action = [hsx|
    <form method="POST" action={action} class="mt-3" style="max-width: 480px;">
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
        <div class="mb-3">
            <label for="idealShiftsPerWeek" class="form-label">Ideal Shifts Per Week</label>
            <input
                id="idealShiftsPerWeek"
                name="idealShiftsPerWeek"
                type="number"
                min="0"
                max="14"
                class="form-control"
                value={maybe "" show staff.idealShiftsPerWeek}
                placeholder="Optional"
            />
        </div>
        <div class="mb-3">
            <label for="isActive" class="form-label">Status</label>
            <select name="isActive" id="isActive" class="form-select">
                <option value="on" selected={staff.isActive}>Active</option>
                <option value="" selected={not staff.isActive}>Inactive</option>
            </select>
        </div>
        <button type="submit" class="btn btn-primary">Save</button>
        <a href={StaffAction} class="btn btn-secondary ms-2">Cancel</a>
    </form>
|]
