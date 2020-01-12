/// <amd-module name='file-uploader'/>

declare var AppConfig: any;

import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

import UI from "./ui";


interface UploadedFile {
    key: string;
    filename: string;
    mime_type: string;
    role?: string;
    created_by?: string;
    create_time?: string;
}

interface ValidationResult {
    valid: boolean;
    errors: string[];
}

interface UploaderState {
    uploaded: UploadedFile[];
    non_deleteable_roles: string[];
    is_readonly: boolean;
    is_role_enabled: boolean;
    validation_status: any;
}

Vue.component('file-uploader', {
    template: `
<div>
    <template v-if="!is_readonly">
        <div class="file-field input-field">
            <div class="btn">
                <span>Upload File(s)</span>
                <input type="file" ref="upload" multiple v-bind:accept="buildAcceptString()" v-on:change="uploadFiles">
            </div>
            <div class="file-path-wrapper">
                <input class="file-path" type="text">
            </div>
        </div>
        <p><small>Supported file types: {{buildFileTypeDisplayString()}}</small></p>
    </template>
    <template v-if="uploaded.length > 0">
        <div class="card">
            <div class="card-content">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 40%">Filename</th>
                            <template v-if="is_role_enabled">
                                <th>Role</th>
                            </template>
                            <th>Created by</th>
                            <th>Create Time</th>
                            <th>Validated</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="file in uploaded">
                            <td>
                                {{file.filename}}
                                <input type="hidden" v-bind:name="buildPath('key')" v-bind:value="file.key"/>
                                <input type="hidden" v-bind:name="buildPath('mime_type')" v-bind:value="file.mime_type"/>
                                <input type="hidden" v-bind:name="buildPath('filename')" v-bind:value="file.filename"/>
                            </td>
                            <template v-if="is_role_enabled">
                                <td>
                                    <template v-if="is_readonly || !is_deleteable(file.role)">
                                        <input type="hidden" v-bind:name="buildPath('role')" v-bind:value="file.role"/>
                                        {{file.role}}
                                    </template>
                                    <template v-else>
                                        <select :name="buildPath('role')" v-model="file.role" class="browser-default">
                                            <option v-for="option in availableRoleOptions(file)" :value="option.value">{{option.label}}</option>
                                        </select>
                                    </template>
                                </td>
                            </template>
                            <td>{{file.created_by}}</td>
                            <td>{{formatTime(file.create_time)}}</td>
                            <td>
                                <template v-if="file.role !== 'IMPORT'">
                                    N/A
                                </template>
                                <template v-else-if="is_valid(file.key)">
                                    Validated
                                </template>
                                <template v-else-if="is_not_yet_validated(file.key)">
                                    Pending
                                </template>
                                <template v-else>
                                    <a href="#" @click.prevent="showErrors(file.key)">Contains Errors</a>
                                </template>
                            </td>
                            <td>
                                <a class="btn" target="_blank" :href="'/file-download?key=' + encodeURIComponent(file.key) + '&filename=' + encodeURIComponent(file.filename) + '&mime_type=' + encodeURIComponent(file.mime_type)">Download</a>
                                <template v-if="!is_readonly && is_deleteable(file.role)">
                                    <a class="btn" v-on:click="remove(file)">Remove</a>
                                </template>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </template>
</div>
`,
    data: function(): UploaderState {
        return {
            uploaded: JSON.parse(this.files),
            non_deleteable_roles: JSON.parse(this.locked_file_roles || "[]"),
            is_readonly: (this.readonly === 'true'),
            is_role_enabled: (this.role === 'enabled'),
            validation_status: {},
        };
    },
    props: ['files', 'csrf_token', 'input_path', 'readonly', 'role', 'submit_button_ids', 'locked_file_roles'],
    methods: {
        uploadFiles: function() {
            const uploadInput = this.$refs.upload as HTMLInputElement;
            const files: FileList|null = uploadInput.files;

            let haveImportFile = Utils.find(this.uploaded, (file) => file.role === 'IMPORT') != null;

            if (files && files.length > 0) {
                const formData = new FormData();
                for (let i = 0; i < files.length; i++) {
                    const file: File|null = files.item(i);
                    if (file) {
                        formData.append('file[]', file);
                    }
                }
                formData.append('authenticity_token', this.csrf_token);

                // If we were handed the IDs of submit buttons, disable those
                // form inputs until we're done uploading.
                this.disableFormSubmit();

                this.$http.post('/file-upload', formData, {
                    headers: {
                        'Content-Type': 'multipart/form-data',
                    },
                    // emulateJSON: true,
                }).then((response: any) => {
                    return response.json();
                }, (response: any) => {
                    this.enableFormSubmit();

                    if (response.status === 415) {
                        // File type not accepted
                        const failures = JSON.parse(response.bodyText);

                        const errors = document.createElement('p');
                        errors.appendChild(document.createTextNode("The following files are not supported types:"));

                        const errorList = document.createElement('ul');

                        for (const failed_file of failures.rejected_files) {
                            const li = document.createElement('li');
                            li.innerText = failed_file;
                            errorList.appendChild(li);
                        }

                        errors.appendChild(errorList);
                        UI.genericHTMLModal(errors);
                    } else {
                        UI.genericModal("File upload failed");
                    }
                }).then((json: UploadedFile[]) => {
                    for (const uploadedFile of json) {
                        if (uploadedFile.role == null) {
                            if (/\.xlsx$/.test(uploadedFile.filename.toLowerCase()) && this.is_role_enabled && !haveImportFile) {
                                uploadedFile.role = 'IMPORT';
                                haveImportFile = true;
                            } else {
                                uploadedFile.role = 'OTHER';
                            }
                        }
                        this.uploaded.push(uploadedFile);
                    }

                    this.enableFormSubmit();
                });
            }
        },
        buildAcceptString(): string {
            return (AppConfig.file_upload_allowed_extensions.map((ext: string) => `.${ext}`)
                    .concat(AppConfig.file_upload_allowed_mime_types)
                    .join(','));
        },
        buildFileTypeDisplayString(): string {
            return AppConfig.file_upload_allowed_extensions.join(', ');
        },
        is_deleteable(role: string) {
            return this.non_deleteable_roles.indexOf(role) < 0;
        },
        remove(fileToRemove: UploadedFile) {
            this.uploaded = Utils.filter(this.uploaded, (file: UploadedFile) => {
                return fileToRemove.key !== file.key;
            });
            this.reset();
        },
        reset() {
            (this.$refs.upload as HTMLInputElement).value = '';
            (document.getElementsByClassName('file-path')[0] as HTMLInputElement).value = '';
        },
        buildPath(field: string) {
            return this.input_path + "[" + field + "]";
        },
        formatTime: function(epochTime: number|null) {
            if (epochTime) {
                return Utils.localDateForEpoch(epochTime);
            } else {
                return '';
            }
        },
        is_valid: function(key: string): boolean {
            if (this.validation_status[key] !== undefined) {
                const status: ValidationResult = (this.validation_status[key] as ValidationResult);
                return status.valid;
            } else {
                return false;
            }
        },
        is_not_yet_validated: function(key: string): boolean {
            return !this.validation_status[key];
        },
        showErrors(key: string) {
            if (this.validation_status[key]) {
                const errors = document.createElement('ul');

                for (const error of this.validation_status[key].errors) {
                    const li = document.createElement('li');
                    li.innerText = error;
                    errors.appendChild(li);
                }

                UI.genericHTMLModal(errors);
            }
        },
        disableFormSubmit() {
            if (this.submit_button_ids) {
                for (const buttonId of this.submit_button_ids) {
                    const button = document.getElementById(buttonId);
                    if (button) {
                        button.classList.add('disabled');
                    }
                }
            }
        },
        enableFormSubmit() {
            if (this.submit_button_ids) {
                for (const buttonId of this.submit_button_ids) {
                    const button = document.getElementById(buttonId);
                    if (button) {
                        button.classList.remove('disabled');
                    }
                }
            }
        },
        setFileValidationStatus() {
            for (const file of this.uploaded) {
                if (file.role === 'IMPORT' && !this.validation_status[file.key]) {
                    this.$http.get('/import-validate', { params: {key: file.key} }).then((response: any) => {
                        return response.json();
                    }, () => {
                        return {
                            errors: ["The file you uploaded could not be opened.  Please make sure you are working with a valid Transfer Metadata Template file."]
                        };
                    }).then((validationResult: ValidationResult) => {
                        this.validation_status[file.key] = validationResult;
                        this.$forceUpdate();
                    });
                }
            }
        },
        availableRoleOptions: function(file: UploadedFile) {
            const importFile = Utils.find(this.uploaded, (f) => f.role === 'IMPORT');

            const availableOptions = [
                { value: "RAP", label: "RAP Notice" },
                { value: "OTHER", label: "Other" },
            ];

            if (!importFile || importFile.key === file.key) {
                return [{ value: "IMPORT", label: "Import" }].concat(availableOptions);
            } else {
                return availableOptions;
            }
        },

    },
    watch: {
        uploaded: {
            handler() {
                this.setFileValidationStatus();
            },
            deep: true,
        },
    },
    mounted: function() {
        this.setFileValidationStatus();
    },
});
