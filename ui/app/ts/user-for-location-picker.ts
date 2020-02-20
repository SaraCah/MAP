/// <amd-module name='user-for-location-picker'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

interface State {
    page: number;
    maxPage: number;
    showNext: boolean;
    records: any[];
    initialised: boolean;
    query: string;
    selectedSort?: string;
}


Vue.component('user-for-location-picker', {
    template: `
<div>
    <div class="card">
        <div class="card-content">
            <form v-on:submit.stop.prevent="searchUsers()">
                <div class="row">
                    <div class="col s12 m3">
                        <div class="input-field">
                            <input type="text" id="q" name="q"></input>
                            <label for="q">Search username/name</label>
                        </div>
                    </div>
                    <div class="col s12 m3">
                        <div class="input-field">
                            <select name="sort">
                                <option value="username_asc">Username A-Z</option>
                                <option value="username_desc">Username Z-A</option>
                                <option value="name_asc">Name A-Z</option>
                                <option value="name_desc">Name Z-A</option>
                                <option value="created_asc">Created Old-New</option>
                                <option value="created_desc">Created New-Old</option>
                            </select>
                            <label>Sort By</label>
                        </div>
                    </div>
                </div>
                <div class="row">
                    <div class="col s12">
                        <button class="btn btn-small" @click="searchUsers()">Search Users</button>
                        <button class="btn btn-small" type="reset" @click="reset()">reset</button>
                    </div>
                </div>
            </form>
            <hr>

            <form class="ajax-form-success"></form>

            <template v-if="initialised">
                <table class="assign-users-table" v-if="records.length > 0">
                    <thead>
                        <tr>
                            <th>Username</th>
                            <th>Name</th>
                            <th>Position</th>
                            <th>Agency</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="record in records">
                            <td>{{record.username}}</td>
                            <td>{{record.name}}</td>
                            <td>{{record.position}}</td>
                            <td>
                                <ul>
                                    <li v-for="agency_label in new Set(record.agency_roles.map((role) => role[0].label))">
                                        {{agency_label}}
                                    </li>
                                </ul>
                            </td>
                            <td>
                                <div class="assign-users-buttons">
                                    <div v-if="allow_senior_admin">
                                        <button @click.stop.prevent="addUserToLocation(record.username, 'SENIOR_AGENCY_ADMIN')" class="right btn btn-small"><i class="fa fa-plus-circle" style="font-size: 1em;"></i> Add Senior Admin</button>
                                        <div class="clearfix"></div>
                                    </div>
                                    <div>
                                        <button @click.stop.prevent="addUserToLocation(record.username, 'AGENCY_ADMIN')" class="right btn btn-small"><i class="fa fa-plus-circle" style="font-size: 1em;"></i> Add Admin</button>
                                        <div class="clearfix"></div>
                                    </div>
                                    <div>
                                        <button @click.stop.prevent="addUserToLocation(record.username, 'AGENCY_CONTACT')" class="right btn btn-small"><i class="fa fa-plus-circle" style="font-size: 1em;"></i> Add Contact</button>
                                        <div class="clearfix"></div>
                                    </div>
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>

                <div class="row">
                    <div class="col s12 center-align">
                        <a :style="page > 0 ? 'visibility: visible' : 'visibility: hidden'" href="javascript:void(0)" v-on:click.stop.prevent="prevPage()"><i class="fa fa-chevron-left"></i> Previous</a>
                        <a :style="(page + 1) < maxPage ? 'visibility: visible' : 'visibility: hidden'" href="javascript:void(0)" v-on:click.stop.prevent="nextPage()">Next <i class="fa fa-chevron-right"></i></a>
                    </div>
                </div>


            </template>
        </div>
    </div>
</div>
`,
    data: function(): State {
        return {
            page: 0,
            maxPage: 0,
            showNext: false,
            records: [],
            initialised: false,
            query: '',
            selectedSort: undefined,
        };
    },
    props: ['locationId', 'csrf_token', 'allow_senior_admin'],
    methods: {
        addUserToLocation: function(username: string, role: string) {
            this.$http.post('/users/assign-to-location', {
                username: username,
                role: role,
                location_id: this.locationId,
                authenticity_token: this.csrf_token,
            }, {
                emulateJSON: true,
            }).then(
                () => {
                    (this.$el.querySelector('form.ajax-form-success') as HTMLFormElement).dispatchEvent(new Event('ajax-success'));
                },
                () => {
                    (this.$el.querySelector('form.ajax-form-success') as HTMLFormElement).dispatchEvent(new Event('ajax-success'));
                });
        },
        searchUsers: function() {
            this.query = (this.$el.querySelector('input[name="q"]') as HTMLInputElement).value;
            this.selectedSort = (this.$el.querySelector('select[name="sort"]') as HTMLInputElement).value;
            this.page = 0;

            this.fireSearch();
        },
        reset: function() {
            this.query = '';
            this.page = 0;
            this.initialised = false;
            this.selectedSort = undefined;

            this.fireSearch();
        },
        nextPage: function() {
            this.page += 1;
            if (this.page >= this.maxPage) {
                this.page = this.maxPage - 1;
            }

            this.fireSearch();
        },
        prevPage: function() {
            this.page -= 1;
            if (this.page < 0) {
                this.page = 0;
            }

            this.fireSearch();
        },
        fireSearch: function() {
            this.$http.get('/users/candidates-for-location', {
                method: 'GET',
                params: {
                    q: this.query,
                    page: this.page,
                    page_size: 5,
                    sort: this.selectedSort,
                    location_id: this.locationId,
                },
            }).then((response: any) => {
                return response.json();
            }, () => {
                // Failed
                this.initialised = true;
                this.records = [];
                this.maxPage = 0;
            }).then((json: any) => {
                this.initialised = true;
                this.maxPage = json.max_page;
                this.records = json.results;
            });
        },
    },
    mounted: function() {
        this.fireSearch();

        M.FormSelect.init(this.$el.querySelectorAll('select'));

        this.$el.querySelectorAll('input,textarea,select').forEach(function(el) {
            if ((el as HTMLFormElement).value !== "") {
                if (el.nextElementSibling) {
                    el.nextElementSibling.classList.add('active');
                }
            }
        });
    },
});
