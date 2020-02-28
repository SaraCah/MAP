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

    <template v-if="!is_readonly">
        <div class="row">
            <div class="col s12">
                <representation-browse v-on:selected="addRequestedItem"
                                       v-on:removed="removeRequestedItem"
                                       :readingRoomRequestsOnly="true"
                                       :selected="requestedItems"
                                       closeButtonLabel="Return to Reading Room Requests">
                </representation-browse>
            </div>
        </div>
    </template>

    <reading-room-request-summary :requested_items="requestedItems"
                                :csrf_token="csrf_token"
                                :request_id="request_id"
                                :lock_version="lock_version"
                                :is_readonly="is_readonly"
                                @remove="removeRequestedItem">
    </reading-room-request-summary>
</div>
`,
    data: function(): {requestedItems: RepresentationRequest[], readonly: boolean} {
        const items: RepresentationRequest[] = [];
        const resolved: any = JSON.parse(this.resolved_representations);

        JSON.parse(this.requested_items).forEach((representationBlob: any) => {
            const rep: RepresentationRequest = new RepresentationRequest(representationBlob.record_ref, '', '', '');
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
    props: ['requested_items',
            'resolved_representations',
            'is_readonly',
            'csrf_token',
            'request_id',
            'lock_version'],
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
                <div class="card-panel blue lighten-5">No items requested.</div>
            </div>
        </div>
    </template>
    <template v-else>
        <div class="card">
            <div class="card-content">
                <span class="card-title" v-if="!is_readonly">Items Requested</span>
                <span class="card-title" v-if="is_readonly">Item Requested</span>
                <reading-room-requested-items-table :requested_items="requested_items"
                                       input_path="requested_item"
                                       :is_readonly="is_readonly"
                                       @remove="removeItem">
                </reading-room-requested-items-table>
            </div>
        </div>
    </template>
</div>
`,
    props: ['requested_items',
            'status',
            'request_id',
            'lock_version',
            'csrf_token',
            'is_readonly'],
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


Vue.component('reading-room-requested-items-table', {
    template: `
<table class="reading-room-request-reading-room-requested-items-table">
    <thead>
        <tr>
            <th style="width:160px">Identifiers</th>
            <th style="min-width: 200px;">Title</th>
            <th>Dates</th>
            <th style="width:80px;">Format</th>
            <th style="min-width: 200px;">Extra Information</th>
            <th v-if="!is_readonly" style="width:40px;"></th>
        </tr>
    </thead>
    <tbody v-for="representation in requested_items">
        <tr v-if="!representation.metadata">
            <td colspan="5">
                <span class="red-text">{{representation.label}}</span>
            </td>
            <td v-if="!is_readonly"></td>
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
                    <p><strong>Intended Use</strong></p>
                    <p>{{representation.metadata.intended_use}}</p>
                </section>

                <section class="extra-info" v-if="representation.metadata.other_restrictions">
                    <p><strong>Other Restrictions</strong></p>
                    <p>{{representation.metadata.other_restrictions}}</p>
                </section>

                <section class="extra-info" v-if="representation.metadata.processing_handling_notes">
                    <p><strong>Processing/Handling Notes</strong></p>
                    <p>{{representation.metadata.processing_handling_notes}}</p>
                </section>
            </td>
            <td v-if="!is_readonly">
                <div class="right-align">
                    <a class="btn btn-small red darken-1" v-on:click="removeItem(representation)" title="Remove"><i class="fa fa-minus-circle" style="font-size: 1em;"></i></a>
                </div>
            </td>
        </tr>
    </tbody>
</table>
`,
    props: ['requested_items', 'input_path', 'is_readonly'],
    methods: {
        buildPath(field: string) {
            return this.input_path + "[" + field + "]";
        },
        removeItem: function(record: Record) {
            this.$emit('remove', record.id);
        },
    },
});
