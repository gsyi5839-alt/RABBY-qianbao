import { useCallback, useMemo, useState } from 'react';

/**
 * Contact item representation for the address book.
 */
export interface ContactItem {
  address: string;
  name: string;
  isAlias?: boolean;
  isContact?: boolean;
}

/**
 * Contact management hook.
 *
 * Manages the local address book with add/remove/update
 * capabilities and search functionality.
 *
 * Modeled after the extension's contactBook model.
 *
 * Note: Contacts are stored in local state for now.
 * TODO: Integrate with a persisted store or API when available.
 */
export function useContact() {
  const [contactsByAddr, setContactsByAddr] = useState<
    Record<string, ContactItem>
  >({});

  const contacts = useMemo(() => {
    return Object.values(contactsByAddr).filter(
      (item): item is ContactItem => !!item?.isContact
    );
  }, [contactsByAddr]);

  const aliases = useMemo(() => {
    return Object.values(contactsByAddr).filter(
      (item): item is ContactItem => !!item?.isAlias
    );
  }, [contactsByAddr]);

  const allEntries = useMemo(() => {
    return Object.values(contactsByAddr);
  }, [contactsByAddr]);

  const getContactByAddress = useCallback(
    (address: string): ContactItem | undefined => {
      return contactsByAddr[address.toLowerCase()];
    },
    [contactsByAddr]
  );

  const addContact = useCallback(
    (contact: ContactItem) => {
      const addr = contact.address.toLowerCase();
      setContactsByAddr((prev) => ({
        ...prev,
        [addr]: {
          ...contact,
          address: addr,
          isContact: true,
        },
      }));
      // TODO: Persist contact to backend when available
      // await contactService.addContact(contact);
    },
    []
  );

  const removeContact = useCallback((address: string) => {
    const addr = address.toLowerCase();
    setContactsByAddr((prev) => {
      const next = { ...prev };
      delete next[addr];
      return next;
    });
    // TODO: Persist removal to backend when available
    // await contactService.removeContact(address);
  }, []);

  const updateContact = useCallback(
    (address: string, update: Partial<ContactItem>) => {
      const addr = address.toLowerCase();
      setContactsByAddr((prev) => {
        const existing = prev[addr];
        if (!existing) return prev;
        return {
          ...prev,
          [addr]: { ...existing, ...update, address: addr },
        };
      });
      // TODO: Persist update to backend when available
    },
    []
  );

  const setAlias = useCallback(
    (address: string, name: string) => {
      const addr = address.toLowerCase();
      setContactsByAddr((prev) => ({
        ...prev,
        [addr]: {
          address: addr,
          name,
          isAlias: true,
          ...prev[addr],
          // name always takes the provided value
        },
      }));
      // Ensure name is set correctly (in case spread overwrote it)
      setContactsByAddr((prev) => ({
        ...prev,
        [addr]: { ...prev[addr], name, isAlias: true },
      }));
    },
    []
  );

  const searchContacts = useCallback(
    (keyword: string): ContactItem[] => {
      if (!keyword) return allEntries;
      const kw = keyword.toLowerCase();
      return allEntries.filter(
        (c) =>
          c.name.toLowerCase().includes(kw) ||
          c.address.toLowerCase().includes(kw)
      );
    },
    [allEntries]
  );

  return {
    // Data
    contacts,
    aliases,
    allEntries,
    contactsByAddr,

    // Actions
    getContactByAddress,
    addContact,
    removeContact,
    updateContact,
    setAlias,
    searchContacts,
  };
}
