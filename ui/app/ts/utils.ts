/// <amd-module name='utils'/>

declare var M: any;

export default class Utils {
    public static filter<T>(array: T[], predicate: (item: T) => boolean): T[] {
        const result: T[] = [];

        array.forEach((item: T) => {
            if (predicate(item)) {
                result.push(item);
            }
        });

        return result;
    }

    public static find<T>(array: T[], predicate: (item: T) => boolean): T | null {
        for (const item of array) {
            if (predicate(item)) {
                return item;
            }
        }

        return null;
    }

    public static genericModal(message: string) {
        const modal = document.createElement('div');
        const content = document.createElement('div');
        modal.appendChild(content);

        modal.className = 'modal';
        content.className = 'modal-content';

        content.innerText = message;

        document.body.appendChild(modal);

        M.Modal.init(modal).open();
    }
}
