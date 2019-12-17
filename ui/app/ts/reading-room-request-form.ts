/// <amd-module name='reading-room-request-form'/>

import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

import Record from "./controlled-records";
import RepresentationRequest from "./representation-linker";

Vue.component('reading-room-request-form', {
    template: `
<div>
    <slot></slot>

    <template v-if="!readonly">
        <div class="row">
            <div class="col s12">
                <representation-browse v-on:selected="addRequestedItem"
                                       v-on:removed="removeRequestedItem"
                                       :readingRoomRequestsOnly="true"
                                       :selected="requestedItems">
                </representation-browse>
            </div>
        </div>
    </template>

    <div class="card">
        <div class="card-content">
            <h4>Requested Items</h4>
            <reading-room-request-summary :requested_items="requestedItems"
                                        :csrf_token="csrf_token"
                                        :request_id="request_id"
                                        :lock_version="lock_version"
                                        @remove="removeRequestedItem">
            </reading-room-request-summary>
        </div>
    </div>
</div>
`,
    data: function(): {requestedItems: RepresentationRequest[], readonly: boolean} {
        const items: RepresentationRequest[] = [];
        const resolved: any = JSON.parse(this.resolved_representations);

        JSON.parse(this.representations).forEach((representationBlob: any) => {
            const rep: RepresentationRequest = new RepresentationRequest(representationBlob.record_ref, '', representationBlob.request_type);
            rep.recordDetails = representationBlob.record_details;
            const resolved_rep = Utils.find(resolved, (item: any) => {
                return item.ref === representationBlob.record_ref;
            });
            if (resolved_rep) {
                rep.metadata = resolved_rep;
                rep.label = rep.metadata.title;
            } else {
                rep.metadata = false;
                rep.label = "You no longer have access to this record.  Please contact QSA for more information."
            }

            items.push(rep);
        });

        return {
            requestedItems: items,
            readonly: this.is_readonly === 'true',
        };
    },
    props: ['representations',
            'resolved_representations',
            'is_readonly',
            'digital_request_status',
            'physical_request_status',
            'csrf_token',
            'request_id',
            'lock_version',
            'digital_request_quote',
            'physical_request_quote',
            'digital_file_issue_id',
            'physical_file_issue_id'],
    methods: {
        addRequestedItem: function(representation: RepresentationRequest) {
            const selectedRepresentation: RepresentationRequest = RepresentationRequest.fromRepresentation(representation);
            this.$http.get('/resolve/representations', {
                method: 'GET',
                params: {
                    'ref[]': selectedRepresentation.id,
                },
            }).then((response: any) => response.json())
                .then((json: any) => {
                    selectedRepresentation.metadata = json[0];
                    selectedRepresentation.label = selectedRepresentation.metadata.title;
                    this.requestedItems.push(selectedRepresentation);
                });
        },
        removeRequestedItem: function(itemToRemoveId: string) {
            this.requestedItems = Utils.filter(this.requestedItems, (item: RepresentationRequest) => {
                return item.id !== itemToRemoveId;
            });
        },
    },
});

Vue.component('reading-room-request-summary', {
    template: `
<div>
    <template v-if="requested_items.length == 0">
        <div class="row">
            <div class="col s12 m12 l6">
                <div class="card-panel blue lighten-5">No {{request_type}} items requested.</div>
            </div>
        </div>
    </template>
    <template v-else>
        <div class="card">
            <div class="card-content">
                <span class="card-title">Items Requested</span>
                <requested-items-table :requested_items="requested_items"
                                       input_path="requested_item"
                                       @remove="removeItem">
                </requested-items-table>
            </div>
        </div>
    </template>
</div>
`,
    props: ['requested_items',
            'status',
            'request_type',
            'request_id',
            'lock_version',
            'csrf_token',
            'quote_blob',
            'file_issue_id'],
    computed: {
        readonly: function(): boolean {
            return (this.$parent as any).readonly;
        },
    },
    methods: {
        removeItem: function(itemId: string) {
            this.$emit('remove', itemId);
        },
    },
    updated: function() {
        this.$el.querySelectorAll('input,textarea,select').forEach(function(el) {
            if ((el as HTMLFormElement).value !== "") {
                if (el.nextElementSibling) {
                    el.nextElementSibling.classList.add('active');
                }
            }
        });
    },
});


Vue.component('requested-items-table', {
    template: `
<table class="reading-room-request-requested-items-table">
    <thead>
        <tr>
            <th style="width:160px">Identifiers</th>
            <th style="min-width: 200px;">Title</th>
            <th>Dates</th>
            <th style="width:80px;">Format</th>
            <th style="min-width: 200px;">Extra Information</th>
            <th v-if="!readonly" style="width:40px;"></th>
        </tr>
    </thead>
    <tbody v-for="representation in requested_items">
        <tr v-if="!representation.metadata">
            <td colspan="5">
                <span class="red-text">{{representation.label}}</span>
            </td>
            <td v-if="!readonly"></td>
        </tr>
        <tr v-if="representation.metadata">
            <td>
                <input type="hidden" :name="buildPath('')" v-bind:value="representation.id"/>

                <div class="identifier">Series:&nbsp;<span class="id">S{{representation.metadata.series_id}}</span></div>
                <div class="identifier">Record:&nbsp;<span class="id">R{{representation.metadata.record_id}}</span></div>

                <div class="identifier" v-if="representation.metadata.agency_assigned_id">
                    Control&nbsp;Number:&nbsp;<span class="id">{{representation.metadata.agency_assigned_id}}</span>
                </div>
                <div class="identifier" v-if="representation.metadata.previous_system_id">
                    Previous&nbsp;System:&nbsp;<span class="id">{{representation.metadata.previous_system_id}}</span>
                </div>
                <div class="identifier" v-if="representation.metadata.representation_id">
                    Representation:&nbsp;<span class="id">{{representation.qsaIdPrefix()}}{{representation.metadata.representation_id}}</span>
                </div>

            <td>{{representation.metadata.title}}</td>

            <td>{{representation.metadata.start_date}} - {{representation.metadata.end_date}}</td>

            <td>{{representation.metadata.format}}</td>

            <td>
                <section class="extra-info" v-if="representation.metadata.intended_use">
                    <h2>Intended Use</h2>
                    <p>{{representation.metadata.intended_use}}</p>
                </section>

                <section class="extra-info" v-if="representation.metadata.other_restrictions">
                    <h2>Other Restrictions</h2>
                    <p>{{representation.metadata.other_restrictions}}</p>
                </section>

                <section class="extra-info" v-if="representation.metadata.processing_handling_notes">
                    <h2>Processing/Handling Notes</h2>
                    <p>{{representation.metadata.processing_handling_notes}}</p>
                </section>
            </td>
            <td v-if="!readonly">
                <div class="right-align">
                    <a class="btn btn-small red darken-1" v-on:click="removeItem(representation)" title="Remove"><i class="fa fa-minus-circle" style="font-size: 1em;"></i></a>
                </div>
            </td>
        </tr>
    </tbody>
</table>
`,
    props: ['requested_items', 'input_path'],
    computed: {
        readonly: function(): boolean {
            return (this.$parent as any).readonly;
        },
    },
    methods: {
        buildPath(field: string) {
            return this.input_path + "[" + field + "]";
        },
        removeItem: function(record: Record) {
            this.$emit('remove', record.id);
        },
    },
});
