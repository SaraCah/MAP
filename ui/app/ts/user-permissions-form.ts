/// <amd-module name='user-permissions-form'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

Vue.component('user-permissions-form', {
    template: `
<div>
    <label for="role">Role</label>
    <select class="browser-default" id="role"name="role" v-model="selectedRole">
        <option value="AGENCY_CONTACT">{{roleLabelFor('Agency Contact')}}</option>
        <option value="AGENCY_ADMIN">{{roleLabelFor('Agency Admin')}}</option>
        <option v-if="is_senior_agency_available" value="SENIOR_AGENCY_ADMIN" >Senior Agency Admin</option>
    </select>

    <div class="row">
        <div class="input-field col s12 required">
            <input id="position" name="position" type="text" v-bind:value="position" required>
            <label class="active" for="position">Position</label>
        </div>
    </div>

    <template v-if="available_permissions.length > 0">
        <div class="row">
            <div class="col s12">
                <strong>Permissions:</strong>
            </div>
        </div>
        <div v-for="permission in available_permissions" class="row">
            <div class="col s12">
                <label><input type="checkbox" name="permissions[]" v-bind:value="permission" v-model="selectedPermissions"> <span>{{permission}}</span></label>
            </div>
        </div>
    </template>

    <template v-if="available_delegations.length > 0">
        <div class="row">
            <div class="col s12">
                <strong>Public Service Act 2008 Delegations:</strong>
            </div>
        </div>
        <div v-for="permission in available_delegations" class="row">
            <div class="col s12">
                <label><input type="checkbox" name="permissions[]" v-bind:value="permission" v-model="selectedPermissions"> <span>{{permission}}</span></label>
            </div>
        </div>
    </template>

    <template v-if="isDelegate">
        <div class="card-panel orange lighten-5">
            In granting this permission, I warrant that the Chief Executive Officer of my agency has delegated this power to the person / position under the Public Service Act 2008 and I have sighted this delegation.
        </div>
    </template>

    <div class="row">
        <br>
        <div class="col s12">
            <button type="submit" class="btn">Save Permissions</button>
        </div>
    </div>
</div>
`,
    data: function(): {
                        selectedRole: string,
                        selectedPermissions: string[],
                      } {
        return {
            selectedRole: this.role,
            selectedPermissions: this.existing_permissions,
        };
    },
    props: ['role', 'position', 'is_senior_agency_available', 'existing_permissions', 'available_permissions', 'available_delegations'],
    computed: {
        isDelegate: function(): boolean {
            return Utils.filter(this.selectedPermissions, (permission: string) => {
                return !!Utils.find(this.available_delegations, (delegationPermission: string) => {
                    return delegationPermission === permission;
                });
            }).length > 0;
        },
    },
    methods: {
        roleLabelFor: function(label: string) {
            if (this.isDelegate) {
                return label + "/Delegate";
            } else {
                return label;
            }
        },
    },
});
