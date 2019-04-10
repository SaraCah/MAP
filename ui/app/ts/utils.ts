export default class Utils {
    static filter<T>(array: T[], predicate: (item: T) => boolean): T[] {
        let result: T[] = [];

        array.forEach((item: T) => {
            if (predicate(item)) {
                result.push(item);
            }
        });

        return result;
    }

    static find<T>(array: T[], predicate: (item: T) => boolean): T | null {
        for (let item of array) {
            if (predicate(item)) {
                return item;
            }
        }

        return null;
    }
}