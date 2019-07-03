/// <amd-module name='manage-agency'/>


import Vue from "vue";
import VueResource from "vue-resource";
import UI from "./ui";
// import Utils from "./utils";


Vue.use(VueResource);

interface State {
    initialised: boolean;
    failed: boolean;
    agency?: Agency;
}

interface Agency {
    label: string;
    locations: LocationWithMembers[];
    is_agency_editable: boolean;
}

interface Location {
    id: number;
    name: string;
    is_top_level: boolean;
}

interface Member {
    user_id: number;
    username: string;
    name: string;
    role: string;
    is_membership_editable?: boolean;
    is_user_editable?: boolean;
}

interface LocationWithMembers {
    location: Location;
    members: Member[];
    is_location_editable: boolean;
}

Vue.component('manage-agency', {
    template: `
<div v-if="initialised">
  <div class="row">
    <div class="col s12">
      <h2>{{this.agency.label}}</h2>
    </div>
  </div>
  <div class="row">
    <div class="col s12 m9 l10">

      <section id="locations" class="scrollspy section">
        <div class="card">
          <div class="card-content">
            <button v-if="agency.is_agency_editable" @click.prevent.default="addLocation()" class="btn right">Add new location</button>

            <h4>Locations</h4>

            <div class="card" v-for="location in this.agency.locations">
              <div class="card-content">
                <div class="right">
                  <button v-if="location.is_location_editable" @click.prevent.default="addUserToLocation(location.location)" class="btn btn-small">Add user to location</button>
                  <button v-if="location.is_location_editable" @click.prevent.default="editLocation(location.location)" class="btn btn-small">Edit location</button>
                </div>
                <h5>{{location.location.name}}</h5>
                <table class="highlight" v-if="location.members.length > 0">
                  <thead>
                    <th>Username</th>
                    <th>Name</th>
                    <th>Role</th>
                    <th>Permissions</th>
                    <th></th>
                  </thead>
                  <tbody>
                    <tr v-for="member in location.members">
                      <td>{{member.username}}</td>
                      <td>{{member.name}}</td>
                      <td>{{member.role}}</td>
                      <td>
                        <ul>
                          <li v-for="permission in member.permissions">
                            {{permission}}
                          </li>
                        </ul>
                      </td>
                      <td>
                        <template v-if="location.is_location_editable && member.is_membership_editable">
                          <button @click.prevent.default="editPermissions(location.location, member)" class="btn btn-small right">Set Permissions</button>
                        </template>
                      </td>
                    </tr>
                  </tbody>
                </table>
                <div v-else>
                  <p>No members for this location</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="users" class="scrollspy section">
        <div class="card">
          <div class="card-content">
            <h4>Users</h4>

            <table>
              <thead>
                <tr>
                  <th>Username</th>
                  <th>Name</th>
                  <th>Role(s)</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="user in this.mergedUsers">
                  <td>{{user.username}}</td>
                  <td>{{user.name}}</td>
                  <td>
                    <ul>
                      <li v-for="role in user.roles">{{role}}</li>
                    </ul>
                  </td>
                  <td>
                    <button  v-if="user.is_user_editable" class="btn btn-small right" @click.prevent.default="editUser(user.username)">Edit User</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>
    </div>
    <div class="col hide-on-small-only m3 l2">
      <ul class="section table-of-contents">
        <li><a href="#locations">Locations</a></li>
        <li><a href="#users">Users</a></li>
      </ul>
    </div>
  </div>
</div>
<div v-else-if="failed">
<p>Could not fetch the agency you requested</p>
</div>

`,
  data: function(): State {
        return {
            initialised: false,
            failed: false,
            agency: undefined,
        };
    },
    props: {
        agency_ref: String,
    },
    methods: {
        refreshAgency: function() {
            this.$http.get(`/agencies/${this.agency_ref}/json`, {
                method: 'GET',
                params: {
                },
            }).then((response: any) => {
                return response.json();
            }, () => {
                // Failed
                this.failed = true;
            }).then((json: any) => {
                if (!this.failed) {
                    this.initialised = true;
                    this.agency = json;
                }
            });
        },
        addLocation: function() {
            this.ajaxFormModal('/locations/new', {
                params: {
                    agency_ref: this.agency_ref,
                },
                successCallback: () => {
                    this.refreshAgency();
                },
            });
        },
        editLocation: function(location: Location) {
            this.ajaxFormModal('/locations/' + location.id, {
                successCallback: () => {
                    this.refreshAgency();
                },
            });
        },
        addUserToLocation: function(location: Location) {
            this.ajaxFormModal('/locations/' + location.id + '/add-user-form', {
                params: {
                    mode: 'new_user',
                },
                successCallback: () => {
                    this.refreshAgency();
                },
            });
        },
        editPermissions: function(location: Location, member: Member) {
            this.ajaxFormModal('/permissions/edit', {
                params: {
                    location_id: location.id,
                    is_top_level: location.is_top_level ? 1 : 0,
                    user_id: member.user_id,
                    username: member.username,
                    role: member.role,
                },
                successCallback: () => {
                    this.refreshAgency();
                },
            });
        },
        ajaxFormModal: function (url: string, opts: any) {
            this.$http.get(url, {
                method: 'GET',
                params: opts.params || {},
            }).then((response: any) => {
                const modalAndContentObj = UI.genericHTMLModal(response.body, ['manage-agency-modal']);

                const modal = modalAndContentObj[0];
                const contentPane = modalAndContentObj[1];

                setTimeout(function () {
                    new AjaxForm(contentPane, () => {
                        modal.close();

                        if (opts.successCallback) {
                            opts.successCallback();
                        }
                    });
                });
            }, () => {
                // failed
            });

        },
        editUser: function(username: string) {
            this.ajaxFormModal('/users/edit', {
                params: {
                    username: username,
                },
                successCallback: () => {
                    this.refreshAgency();
                },
            });
        }
    },
    computed: {
        mergedUsers: function(): object[] {
            interface AggregatedMember {
                username: string;
                name: string;
                roles: string[];
                is_user_editable: boolean;
            }

            const usernames: string[] = [];
            const users: { [username: string]: AggregatedMember } = {};

            if (!this.agency) {
                return [];
            }

            for (const location of this.agency.locations) {
                for (const member of location.members) {
                    if (!users[member.username]) {
                        usernames.push(member.username);
                        users[member.username] = {
                            username: member.username,
                            name: member.name,
                            roles: [],
                            is_user_editable: false,
                        };
                    }

                    // \u2014 = emdash
                    users[member.username].roles.push(location.location.name + " \u2014 " + member.role);
                    if (member.is_user_editable) {
                        users[member.username].is_user_editable = true;
                    }
                }
            }

            const result: AggregatedMember[] = [];
            usernames.sort();

            for (const username of usernames) {
                result.push(users[username]);
            }

            return result;
        },
    },
    mounted: function() {
        this.refreshAgency();
    },
});

