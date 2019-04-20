/// <amd-module name='linker'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

import Utils from "./utils";

interface Agency {
    id: number;
    label: string;
}

class AgencyRole {
    public static fromAgency(a: Agency): AgencyRole {
        return new AgencyRole(a.id, a.label, 'SENIOR_AGENCY_ADMIN');
    }

    public locationId?: number;
    public locationOptions: Location[];
    public permissions: string[];
    public permissionOptions: string[];

    constructor(public id: number,
                public label: string,
                public role: string) {
        this.locationId = undefined;
        this.locationOptions = [];
        this.permissions = [];
        this.permissionOptions = [];
    }

    public populateFromJSON(json: any) {
        this.locationOptions = json.location_options;
        this.permissionOptions = json.permission_options;

        if (this.locationOptions.length > 0) {
            this.locationId = this.locationOptions[0].id;
        }
    }
}

interface Location {
    id: number;
    label: string;
}

Vue.component('agency-typeahead', {
    template: `
<div>
  <input id="agency-typeahead" v-on:keyup="handleInput" type="text" v-model="text" ref="text"></input>
  <label for="agency-typeahead">Agency</label>
  <ul>
    <li v-for="agency in matches">
      <a href="javascript:void(0);" v-on:click="select(agency)">{{ agency.label }}</a>
    </li>
  </ul>
</div>
`,
    data: function(): {matches: Agency[], text: string} {
        return {
            matches: [],
            text: '',
        };
    },
    methods: {
        handleInput() {
            if (this.text.length > 3) {
                this.$http.get('/search/agencies', {
                    method: 'GET',
                    params: {
                        q: this.text,
                    },
                }).then((response: any) => {
                    return response.json();
                }, () => {
                    this.matches = [];
                }).then((json: any) => {
                    this.matches = json;
                });
            }
        },
        select(agency: Agency) {
            this.$emit('selected', agency);
            this.matches = [];
            this.text = '';
            (this.$refs.text as HTMLElement).focus();
        },
    },
});

Vue.component('agency-linker', {
    template: `
<div class="input-field col s12">
  <agency-typeahead v-on:selected="addSelected"></agency-typeahead>
  <input type="hidden" name="location[agency_ref]" v-bind:value="selected.id"/>
  <strong v-bind:value="selected.label">{{selected.label}}</strong>
</div>
`,
    data: function(): {selected: Agency} {
        return {
            selected: JSON.parse(this.agency),
        };
    },
    props: ['agency'],
    methods: {
        addSelected(agency: Agency) {
            this.selected = agency;
        },
    },
});

Vue.component('agency-role-linker', {
    template: `
<div class="input-field col s12">
  <agency-typeahead v-on:selected="addSelected"></agency-typeahead>
  <table class="user-role-table">
    <thead><tr><th style="width: 40%;">Agency</th><th style="width: 20%;">Location</th><th style="width: 20%;">Role</th><th></th></tr></thead>
    <tbody v-for="agency in selected">
      <tr>
        <td>
          {{agency.label}}
          <input type="hidden" name="user[agency][][id]" v-bind:value="agency.id"/>
          <input type="hidden" name="user[agency][][label]" v-bind:value="agency.label"/>
        </td>
        <td>
          <template v-if="agency.role !== 'SENIOR_AGENCY_ADMIN'">
              <div v-if="agency.locationOptions.length == 0">Agency Top Level Location</div>
              <div v-if="agency.locationOptions.length > 0">
                  <select class="browser-default" name="user[agency][][location_id]" v-bind:value="agency.locationId" v-model="agency.locationId">
                    <option v-for="location in agency.locationOptions" v-bind:value="location.id">{{ location.label }}</option>
                  </select>
                  <div v-for="location in agency.locationOptions">
                      <input type="hidden" name="user[agency][][location_options][][id]" v-bind:value="location.id" />
                      <input type="hidden" name="user[agency][][location_options][][label]" v-bind:value="location.label" />
                  </div>
              </div>
          </template>
          <template v-if="agency.role === 'SENIOR_AGENCY_ADMIN'">N/A</template>
        </td>
        <td>
          <select class="browser-default" name="user[agency][][role]" v-model="agency.role">
            <option value="SENIOR_AGENCY_ADMIN">Senior Agency Admin</option>
            <option value="AGENCY_ADMIN">Agency Admin</option>
            <option value="AGENCY_CONTACT">Agency Contact</option>
          </select>
        </td>
        <td>
          <button class="btn" v-on:click="removeSelected(agency)">Remove</button>
        </td>
      </tr>
      <tr>
        <td></td>
        <td></td>
        <td>
            <div v-if="agency.role !== 'SENIOR_AGENCY_ADMIN'">
                <div v-for="permission_type in agency.permissionOptions">
                    <label>
                        <input type="checkbox" name="user[agency][][permission][]" v-bind:value="permission_type" v-on:change="togglePermission($event, permission_type, agency)">
                        <span>{{ permission_type }}</span>
                    </label>
                </div>
            </div>
        </td>
        <td></td>
      </tr>
    </tbody>
  </table>
</div>
`,
    data: function(): {selected: AgencyRole[]} {
        return {
            selected: JSON.parse(this.agencies),
        };
    },
    props: ['agencies'],
    methods: {
        removeSelected(agencyToRemove: AgencyRole) {
            this.selected = Utils.filter(this.selected, (agency: AgencyRole) => {
                return agency.id !== agencyToRemove.id;
            });
        },
        addSelected(agency: Agency) {
            const selectedAgency: AgencyRole = AgencyRole.fromAgency(agency);

            this.$http.get('/linker_data_for_agency', {
                method: 'GET',
                params: {
                    agency_ref: selectedAgency.id,
                },
            }).then((response: any) => response.json())
              .then((json: any) => {
                  selectedAgency.populateFromJSON(json);
                  this.selected.push(selectedAgency);
              });
        },
        togglePermission(event: any, permission: string, agency: AgencyRole) {
            if (event.target.checked) {
                agency.permissions.push(permission);
            } else {
                agency.permissions.splice(agency.permissions.indexOf(permission), 1);
            }
        },
    },
});

// class AgencyLinker {
//
//     constructor($input) {
//         this.$input = $input;
//         this.$hiddenInputId = $input.siblings('.morty-relationship-object-id');
//         this.$hiddenInputRepository = this.$input.siblings('morty-relationship-object-repository');
//
//         this.$autocomplete = $('<ul id="ac" class="autocomplete-content dropdown-content"'
//                                + 'style="position:absolute"></ul>');
//         this.$inputDiv = this.$input.closest('.input-field');
//
//         this.request = undefined;
//         this.runningRequest = false;
//         this.timeout = undefined;
//         this.liSelected = undefined;
//         this.next = undefined;
//
//         this.types = [];
//
//         this.init();
//     }
//
//     init() {
//         var self = this;
//
//         if (self.$inputDiv.length) {
//             self.$inputDiv.append(self.$autocomplete); // Set ul in body
//         } else {
//             self.$input.after(self.$autocomplete);
//         }
//
//
//         self.$autocomplete.on('click', 'li', function (event) {
//             event.preventDefault();
//             event.stopPropagation();
//
//             self.$input.val('');
//             self.$hiddenInputId.val('');
//             self.$hiddenInputRepository.val('');
//             self.$input.siblings('.prefix').remove();
//
//             if ($(this).data('id')) {
//                 self.$input.val($(this).data('display_string'));
//                 self.$hiddenInputId.val($(this).data('id'));
//                 self.$hiddenInputRepository.val($(this).data('repository'));
//
//                 if ($(this).data('icon')) {
//                     var $icon = $($(this).data('icon'));
//                     $icon.addClass('prefix');
//                     self.$input.before($icon);
//                 }
//             }
//
//             self.$autocomplete.empty();
//             self.$input.focus();
//         });
//
//         self.$input.on('keydown', function (e) {
//             if (e.which === 13) { // select element with Enter
//                 e.preventDefault();
//                 e.stopPropagation();
//
//                 self.liSelected[0].click();
//                 return false;
//             }
//             return true;
//         });
//
//         self.$input.on('keyup', function (e) {
//
//             if (self.timeout) { // comment to remove timeout
//                 clearTimeout(self.timeout);
//             }
//
//             if (self.runningRequest) {
//                 self.request.abort();  // stop requests that are already sent
//             }
//
//             if (e.which === 13) { // select element with Enter
//                 self.liSelected[0].click();
//                 return false;
//             }
//
//             // scroll ul with arrow keys
//             if (e.which === 40) {   // down arrow
//                 if (self.liSelected) {
//                     self.liSelected.removeClass('selected');
//                     self.next = self.liSelected.next();
//                     if (self.next.length > 0) {
//                         self.liSelected = self.next.addClass('selected');
//                     } else {
//                         self.liSelected = self.$autocomplete.find('li').eq(0).addClass('selected');
//                     }
//                 } else {
//                     self.liSelected = self.$autocomplete.find('li').eq(0).addClass('selected');
//                 }
//                 return; // stop new AJAX call
//             } else if (e.which === 38) { // up arrow
//                 if (self.liSelected) {
//                     self.liSelected.removeClass('selected');
//                     self.next = self.liSelected.prev();
//                     if (self.next.length > 0) {
//                         self.liSelected = self.next.addClass('selected');
//                     } else {
//                         self.liSelected = self.$autocomplete.find('li').last().addClass('selected');
//                     }
//                 } else {
//                     self.liSelected = self.$autocomplete.find('li').last().addClass('selected');
//                 }
//                 return;
//             }
//
//             // escape these keys
//             if (e.which === 9 ||        // tab
//                 e.which === 16 ||       // shift
//                 e.which === 17 ||       // ctrl
//                 e.which === 18 ||       // alt
//                 e.which === 20 ||       // caps lock
//                 e.which === 35 ||       // end
//                 e.which === 36 ||       // home
//                 e.which === 37 ||       // left arrow
//                 e.which === 39) {       // right arrow
//                 return;
//             } else if (e.which === 27) { // Esc. Close ul
//                 self.$autocomplete.empty();
//                 return;
//             }
//
//             var val = self.$input.val().toLowerCase();
//             self.$autocomplete.empty();
//
//             if (val.length >= 1) {
//                 self.timeout = setTimeout(function () {
//                     self.runningRequest = true;
//                     self.request = $.ajax({
//                         type: 'GET',
//                         url: '/search/typeahead',
//                         data: {
//                             q: val,
//                             type: self.types,
//                         },
//                         success: function (data) {
//                             if (data.length > 0) {
//                                 var appendList = [];
//                                 data.forEach(function(result) {
//                                     var $li = $('<li>');
//                                     var $span = $('<span>').html(self.highlight(result.display_string, val));
//                                     $span.prepend($(result.icon).addClass('left'));
//                                     $li.append($span);
//                                     $li.data('id', result.id);
//                                     $li.data('display_string', result.display_string);
//                                     $li.data('icon', result.icon);
//                                     $li.data('repository', result.repository);
//                                     appendList.push($li);
//                                 });
//                                 self.$autocomplete.append(appendList);   // finally appending everything
//                             }else{
//                                 self.$autocomplete.append($('<li><span>No matches</span></li>'));
//                             }
//                         },
//                         complete: function () {
//                             self.runningRequest = false;
//                         }
//                     });
//                 }, 250);
//             }
//         });
//
//         $(document).click(function (event) { // close ul if clicked outside
//             if (!$(event.target).closest(self.$autocomplete).length) {
//                 self.$autocomplete.empty();
//             }
//         });
//     }
//
//     highlight(string, match) {
//         var matchStart = string.toLowerCase().indexOf("" + match.toLowerCase() + ""),
//         matchEnd = matchStart + match.length - 1,
//         beforeMatch = string.slice(0, matchStart),
//         matchText = string.slice(matchStart, matchEnd + 1),
//         afterMatch = string.slice(matchEnd + 1);
//         string = "<span>" + beforeMatch + "<span class='highlight'>" +
//             matchText + "</span>" + afterMatch + "</span>";
//         return string;
//     }
//
//     reset_for_types: (types) {
//         this.$input.val('');
//         this.$hiddenInputId.val('');
//         this.$hiddenInputRepository.val('');
//
//         this.$input.siblings('.prefix').remove();
//         this.types = types;
//     }
//
//     disable() {
//         this.$input.prop('disabled', true);
//         this.$hiddenInputId.prop('disabled', true);
//         this.$hiddenInputRepository.prop('disabled', true);
//     }
//
//     enable() {
//         this.$input.prop('disabled', false);
//         this.$hiddenInputId.prop('disabled', false);
//         this.$hiddenInputRepository.prop('disabled', false);
//     }
// }
