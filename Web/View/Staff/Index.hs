module Web.View.Staff.Index where

import Web.View.Prelude

data IndexView = IndexView
    { staffMembers :: [Staff]
    , staffFilter  :: Text
    }

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

        {renderFilterTabs staffFilter}

        <table class="table table-striped">
            <thead>
                <tr>
                    <th>First Name</th>
                    <th>Last Name</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                {forEach staffMembers renderStaffRow}
            </tbody>
        </table>
    |]

renderFilterTabs :: Text -> Html
renderFilterTabs active = [hsx|
    <ul class="nav nav-tabs mb-3">
        <li class="nav-item">
            <a class={allClass} href={pathTo StaffAction}>All</a>
        </li>
        <li class="nav-item">
            <a class={trialClass} href={trialUrl}>Trial</a>
        </li>
        <li class="nav-item">
            <a class={linkedClass} href={linkedUrl}>Linked</a>
        </li>
    </ul>
|]
    where
        trialUrl    = pathTo StaffAction <> "?filter=trial"
        linkedUrl   = pathTo StaffAction <> "?filter=linked"
        allClass    = "nav-link" <> if active == "all" then " active" else "" :: Text
        trialClass  = "nav-link" <> if active == "trial" then " active" else "" :: Text
        linkedClass = "nav-link" <> if active == "linked" then " active" else "" :: Text

renderStaffRow :: Staff -> Html
renderStaffRow staff = [hsx|
    <tr>
        <td><a href={ShowStaffAction staff.id}>{staff.firstName}</a></td>
        <td>{staff.lastName}</td>
        <td>{renderTypeBadge staff}</td>
        <td>{renderStatusBadge staff}</td>
        <td class="text-end">
            <a href={EditStaffAction staff.id} class="btn btn-sm btn-outline-secondary me-1">Edit</a>
            <a href={DeleteStaffAction staff.id} class="btn btn-sm btn-outline-danger js-delete js-delete-no-confirm">Delete</a>
        </td>
    </tr>
|]

renderTypeBadge :: Staff -> Html
renderTypeBadge staff
    | isTrialStaff staff = [hsx|<span class="badge bg-warning text-dark">Trial</span>|]
    | otherwise          = [hsx|<span class="badge bg-info text-dark">Linked</span>|]

renderStatusBadge :: Staff -> Html
renderStatusBadge staff
    | staff.isActive = [hsx|<span class="badge bg-success">Active</span>|]
    | otherwise      = [hsx|<span class="badge bg-secondary">Inactive</span>|]
