module Web.View.Staff.Index where

import Web.View.Prelude

newtype IndexView = IndexView { staffMembers :: [Staff] }

instance View IndexView where
    html IndexView { .. } = [hsx|
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href={DashboardAction}>Dashboard</a></li>
                <li class="breadcrumb-item active">Staff</li>
            </ol>
        </nav>

        <div class="d-flex justify-content-between align-items-center mb-3">
            <h1>Staff</h1>
            <a href={NewStaffAction} class="btn btn-primary">New Staff Member</a>
        </div>

        <table class="table table-striped">
            <thead>
                <tr>
                    <th>First Name</th>
                    <th>Last Name</th>
                    <th>Status</th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                {forEach staffMembers renderStaffRow}
            </tbody>
        </table>
    |]

renderStaffRow :: Staff -> Html
renderStaffRow staff = [hsx|
    <tr>
        <td><a href={ShowStaffAction staff.id}>{staff.firstName}</a></td>
        <td>{staff.lastName}</td>
        <td>{renderStatusBadge staff}</td>
        <td class="text-end">
            <a href={EditStaffAction staff.id} class="btn btn-sm btn-outline-secondary me-1">Edit</a>
            <a href={DeleteStaffAction staff.id} class="btn btn-sm btn-outline-danger js-delete js-delete-no-confirm">Delete</a>
        </td>
    </tr>
|]

renderStatusBadge :: Staff -> Html
renderStatusBadge staff
    | staff.isActive = [hsx|<span class="badge bg-success">Active</span>|]
    | otherwise      = [hsx|<span class="badge bg-secondary">Inactive</span>|]
