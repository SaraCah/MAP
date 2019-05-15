/// <amd-module name='file-issue-form'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";
// import Utils from "./utils";
// import UI from "./ui";
Vue.use(VueResource);
// import Utils from "./utils";
import RepresentationRequest from "./representation-linker";

Vue.component('file-issue-form', {
    template: `
<div>
    <section id="items" class="scrollspy section card">
        <div class="card-content">
            <representation-linker ref="linker" :input_path="input_path" :representations="representations" @change="refreshSummaries()"></representation-linker>
        </div>
    </section>

    <slot></slot>

    <section id="digitalRequest" class="scrollspy section">
        <h4>Digital Request Summary</h4>
        <file-issue-digital-request ref="digitalRequest"></file-issue-digital-request>
    </section>

    <section id="physicalRequest" class="scrollspy section">
        <h4>Physical Request Summary</h4>
        <file-issue-physical-request ref="physicalRequest"></file-issue-physical-request>
    </section>
</div>
`,
    data: function(): {} {
        return {};
    },
    props: ['input_path', 'representations'],
    methods: {
        refreshSummaries: function() {
            // FIXME type?
            const digitalRequest:any = this.$refs.digitalRequest;
            digitalRequest.syncItems(this.getDigitalRepresentations());
            const physicalRequest:any = this.$refs.physicalRequest;
            physicalRequest.syncItems(this.getPhysicalRepresentations());
        },
        getDigitalRepresentations: function() {
            // FIXME type? 
            const linker:any = this.$refs.linker;
            return Utils.filter(linker.getSelected(), (rep:RepresentationRequest) => {
                return rep.request_type == 'DIGITAL';
            });
        },
        getPhysicalRepresentations: function() {
            // FIXME type? 
            const linker:any = this.$refs.linker;
            return Utils.filter(linker.getSelected(), (rep:RepresentationRequest) => {
                return rep.request_type == 'PHYSICAL';
            });
        },
    },
    mounted: function() {
        console.log("MOUNTED: file-issue-form");
        this.refreshSummaries();
    }
});

Vue.component('file-issue-physical-request', {
    template: `
<div>
    <template v-if="items.length == 0">
        No physical items requested
    </template>
    <template v-else>
        <ul>
            <li v-for="item in items">
                {{item.label}}
            </li>
        </ul>
    </template>
</div>
`,
    data: function(): {items: RepresentationRequest[]} {
        return {
            items: [],
        };
    },
    methods: {
        syncItems: function(reps:RepresentationRequest[]) {
            this.items = reps;
        }
    },
    mounted: function() {
        console.log("MOUNTED: file-issue-physical-request");
    }
});

Vue.component('file-issue-digital-request', {
    template: `
<div>
    <template v-if="items.length == 0">
        No digital items requested
    </template>
    <template v-else>
        <ul>
            <li v-for="item in items">
                {{item.label}}
            </li>
        </ul>
    </template>
</div>
`,
    data: function(): {items:RepresentationRequest[]} {
        return {
            items: [],
        };
    },
    methods: {
        syncItems: function(reps:RepresentationRequest[]) {
            this.items = reps;
        }
    },
    mounted: function() {
        console.log("MOUNTED: file-issue-digital-request");
    }
});
