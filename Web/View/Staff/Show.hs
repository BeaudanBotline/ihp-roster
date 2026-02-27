module Web.View.Staff.Show where

import Web.View.Prelude

newtype ShowView = ShowView { staff :: Staff }

instance View ShowView where
    html ShowView { .. } = [hsx|
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href={DashboardAction}>Dashboard</a></li>
                <li class="breadcrumb-item"><a href={StaffAction}>Staff</a></li>
                <li class="breadcrumb-item active">{staff.firstName} {staff.lastName}</li>
            </ol>
        </nav>

        <div class="d-flex justify-content-between align-items-center mb-3">
            <h1>{staff.firstName} {staff.lastName}</h1>
            <div>
                <a href={EditStaffAction staff.id} class="btn btn-outline-secondary me-1">Edit</a>
                <a href={DeleteStaffAction staff.id} class="btn btn-outline-danger js-delete js-delete-no-confirm">Delete</a>
            </div>
        </div>

        <dl class="row" style="max-width: 480px;">
            <dt class="col-sm-4">First Name</dt>
            <dd class="col-sm-8">{staff.firstName}</dd>

            <dt class="col-sm-4">Last Name</dt>
            <dd class="col-sm-8">{staff.lastName}</dd>

            <dt class="col-sm-4">Type</dt>
            <dd class="col-sm-8">{renderTypeBadge staff}</dd>

            <dt class="col-sm-4">Status</dt>
            <dd class="col-sm-8">{renderStatusBadge staff}</dd>

            <dt class="col-sm-4">Created</dt>
            <dd class="col-sm-8">{staff.createdAt |> timeAgo}</dd>
        </dl>
    |]

renderTypeBadge :: Staff -> Html
renderTypeBadge staff
    | isTrialStaff staff = [hsx|<span class="badge bg-warning text-dark">Trial</span>|]
    | otherwise          = [hsx|<span class="badge bg-info text-dark">Linked</span>|]

renderStatusBadge :: Staff -> Html
renderStatusBadge staff
    | staff.isActive = [hsx|<span class="badge bg-success">Active</span>|]
    | otherwise      = [hsx|<span class="badge bg-secondary">Inactive</span>|]
