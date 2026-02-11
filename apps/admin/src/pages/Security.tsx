import React, { useEffect, useMemo, useRef, useState } from 'react';
import type {
  SecurityRule,
  SecuritySeverity,
  PhishingEntry,
  ContractWhitelistEntry,
  SecurityAlert,
} from '@rabby/shared';
import {
  getWhitelist,
  addToWhitelist,
  removeFromWhitelist,
  getSecurityRules,
  createSecurityRule,
  updateSecurityRule,
  deleteSecurityRule,
  getPhishingEntries,
  createPhishingEntry,
  updatePhishingEntry,
  deletePhishingEntry,
  getContractWhitelist,
  createContractWhitelistEntry,
  updateContractWhitelistEntry,
  deleteContractWhitelistEntry,
  getSecurityAlerts,
  updateSecurityAlert,
} from '../services/admin';

const SEVERITY_OPTIONS: SecuritySeverity[] = ['critical', 'high', 'medium', 'low'];

const SEVERITY_STYLES: Record<SecuritySeverity, React.CSSProperties> = {
  critical: {
    background: 'var(--r-red-light, #fff1f0)',
    color: 'var(--r-red-default, #cf1322)',
    border: '1px solid #ffa39e',
  },
  high: {
    background: 'var(--r-orange-light, #fff2e8)',
    color: 'var(--r-orange-default, #d4380d)',
    border: '1px solid #ffbb96',
  },
  medium: {
    background: 'var(--r-orange-light, #fff7e6)',
    color: '#d46b08',
    border: '1px solid #ffd591',
  },
  low: {
    background: 'var(--r-green-light, #f6ffed)',
    color: 'var(--r-green-default, #389e0d)',
    border: '1px solid #b7eb8f',
  },
};

const STATUS_STYLES: Record<string, React.CSSProperties> = {
  confirmed: {
    background: 'var(--r-red-light, #fff2f0)',
    color: 'var(--r-red-default, #cf1322)',
    border: '1px solid #ffccc7',
  },
  pending: {
    background: 'var(--r-orange-light, #fff7e6)',
    color: '#d46b08',
    border: '1px solid #ffd591',
  },
  active: {
    background: 'var(--r-green-light, #f6ffed)',
    color: 'var(--r-green-default, #389e0d)',
    border: '1px solid #b7eb8f',
  },
  disabled: {
    background: 'var(--r-orange-light, #fff7e6)',
    color: '#d46b08',
    border: '1px solid #ffd591',
  },
  open: {
    background: 'var(--r-orange-light, #fff7e6)',
    color: '#d46b08',
    border: '1px solid #ffd591',
  },
  resolved: {
    background: 'var(--r-green-light, #f6ffed)',
    color: 'var(--r-green-default, #389e0d)',
    border: '1px solid #b7eb8f',
  },
};

const thStyle: React.CSSProperties = {
  textAlign: 'left',
  padding: '12px 16px',
  borderBottom: '2px solid var(--r-neutral-line, #f0f0f0)',
  color: 'var(--r-neutral-foot, #6a7587)',
  fontWeight: 600,
  fontSize: 12,
  textTransform: 'uppercase',
  letterSpacing: '0.5px',
  background: 'var(--r-neutral-bg-3, #fafafa)',
};

const tdStyle: React.CSSProperties = {
  padding: '12px 16px',
  borderBottom: '1px solid var(--r-neutral-line, #f0f0f0)',
  color: 'var(--r-neutral-body, #3e495e)',
  fontSize: 13,
};

const inputStyle: React.CSSProperties = {
  width: '100%',
  padding: '6px 10px',
  borderRadius: 6,
  border: '1px solid var(--r-neutral-line, #d9d9d9)',
  fontSize: 12,
};

const selectStyle: React.CSSProperties = {
  padding: '6px 10px',
  borderRadius: 6,
  border: '1px solid var(--r-neutral-line, #d9d9d9)',
  fontSize: 12,
  background: '#fff',
};

export default function SecurityPage() {
  const [activeTab, setActiveTab] = useState<
    'rules' | 'phishing' | 'whitelist' | 'contracts' | 'alerts'
  >('rules');
  const [search, setSearch] = useState('');

  const [rules, setRules] = useState<SecurityRule[]>([]);
  const [phishing, setPhishing] = useState<PhishingEntry[]>([]);
  const [contracts, setContracts] = useState<ContractWhitelistEntry[]>([]);
  const [alerts, setAlerts] = useState<SecurityAlert[]>([]);

  const [rulesLoading, setRulesLoading] = useState(false);
  const [phishingLoading, setPhishingLoading] = useState(false);
  const [contractsLoading, setContractsLoading] = useState(false);
  const [alertsLoading, setAlertsLoading] = useState(false);

  const [whitelistAddresses, setWhitelistAddresses] = useState<string[]>([]);
  const [newWhitelistAddr, setNewWhitelistAddr] = useState('');
  const [whitelistLoading, setWhitelistLoading] = useState(false);
  const whitelistInputRef = useRef<HTMLInputElement>(null);

  const [showCreateRule, setShowCreateRule] = useState(false);
  const [showCreatePhishing, setShowCreatePhishing] = useState(false);
  const [showCreateContract, setShowCreateContract] = useState(false);

  const [newRule, setNewRule] = useState({
    name: '',
    description: '',
    type: 'transfer',
    severity: 'medium' as SecuritySeverity,
    enabled: true,
  });

  const [newPhishing, setNewPhishing] = useState({
    domain: '',
    address: '',
    type: 'phishing',
    reportedBy: 'manual',
    status: 'pending',
  });

  const [newContract, setNewContract] = useState({
    address: '',
    name: '',
    chainId: '',
    status: 'active',
  });

  const [editingRuleId, setEditingRuleId] = useState<string | null>(null);
  const [ruleDraft, setRuleDraft] = useState<SecurityRule | null>(null);

  const [editingPhishingId, setEditingPhishingId] = useState<string | null>(null);
  const [phishingDraft, setPhishingDraft] = useState<PhishingEntry | null>(null);

  const [editingContractId, setEditingContractId] = useState<string | null>(null);
  const [contractDraft, setContractDraft] =
    useState<ContractWhitelistEntry | null>(null);

  const loadRules = async () => {
    setRulesLoading(true);
    try {
      const res = await getSecurityRules();
      setRules(res.list || []);
    } catch {
      setRules([]);
    } finally {
      setRulesLoading(false);
    }
  };

  const loadPhishing = async () => {
    setPhishingLoading(true);
    try {
      const res = await getPhishingEntries();
      setPhishing(res.list || []);
    } catch {
      setPhishing([]);
    } finally {
      setPhishingLoading(false);
    }
  };

  const loadContracts = async () => {
    setContractsLoading(true);
    try {
      const res = await getContractWhitelist();
      setContracts(res.list || []);
    } catch {
      setContracts([]);
    } finally {
      setContractsLoading(false);
    }
  };

  const loadAlerts = async () => {
    setAlertsLoading(true);
    try {
      const res = await getSecurityAlerts();
      setAlerts(res.list || []);
    } catch {
      setAlerts([]);
    } finally {
      setAlertsLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'rules') loadRules();
    if (activeTab === 'phishing') loadPhishing();
    if (activeTab === 'contracts') loadContracts();
    if (activeTab === 'alerts') loadAlerts();
    if (activeTab === 'whitelist') {
      setWhitelistLoading(true);
      getWhitelist()
        .then((res) => setWhitelistAddresses(res.addresses || []))
        .catch(() => setWhitelistAddresses([]))
        .finally(() => setWhitelistLoading(false));
    }
    setEditingRuleId(null);
    setRuleDraft(null);
    setEditingPhishingId(null);
    setPhishingDraft(null);
    setEditingContractId(null);
    setContractDraft(null);
    setShowCreateRule(false);
    setShowCreatePhishing(false);
    setShowCreateContract(false);
  }, [activeTab]);

  const handleAddWhitelist = async () => {
    const addr = newWhitelistAddr.trim();
    if (!/^0x[0-9a-fA-F]{40}$/.test(addr)) return;
    try {
      const res = await addToWhitelist(addr);
      setWhitelistAddresses(res.addresses || []);
      setNewWhitelistAddr('');
    } catch {}
  };

  const handleRemoveWhitelist = async (address: string) => {
    try {
      const res = await removeFromWhitelist(address);
      setWhitelistAddresses(res.addresses || []);
    } catch {}
  };

  const handleCreateRule = async () => {
    if (!newRule.name || !newRule.description || !newRule.type) return;
    const created = await createSecurityRule({
      name: newRule.name,
      description: newRule.description,
      type: newRule.type,
      severity: newRule.severity,
      enabled: newRule.enabled,
      triggers: 0,
    });
    setRules((prev) => [created, ...prev]);
    setShowCreateRule(false);
    setNewRule({
      name: '',
      description: '',
      type: 'transfer',
      severity: 'medium',
      enabled: true,
    });
  };

  const handleCreatePhishing = async () => {
    if (!newPhishing.domain || !newPhishing.address || !newPhishing.type) return;
    const created = await createPhishingEntry({
      domain: newPhishing.domain,
      address: newPhishing.address,
      type: newPhishing.type,
      reportedBy: newPhishing.reportedBy,
      status: newPhishing.status as 'confirmed' | 'pending',
      addedDate: new Date().toISOString().slice(0, 10),
    });
    setPhishing((prev) => [created, ...prev]);
    setShowCreatePhishing(false);
    setNewPhishing({
      domain: '',
      address: '',
      type: 'phishing',
      reportedBy: 'manual',
      status: 'pending',
    });
  };

  const handleCreateContract = async () => {
    if (!newContract.address) return;
    const created = await createContractWhitelistEntry({
      address: newContract.address,
      name: newContract.name || undefined,
      chainId: newContract.chainId || undefined,
      status: newContract.status as 'active' | 'disabled',
      addedDate: new Date().toISOString().slice(0, 10),
    });
    setContracts((prev) => [created, ...prev]);
    setShowCreateContract(false);
    setNewContract({ address: '', name: '', chainId: '', status: 'active' });
  };

  const handleToggleRule = async (rule: SecurityRule) => {
    const updated = await updateSecurityRule(rule.id, { enabled: !rule.enabled });
    setRules((prev) => prev.map((r) => (r.id === rule.id ? updated : r)));
  };

  const handleSaveRule = async () => {
    if (!ruleDraft || !editingRuleId) return;
    const updated = await updateSecurityRule(editingRuleId, {
      name: ruleDraft.name,
      description: ruleDraft.description,
      type: ruleDraft.type,
      severity: ruleDraft.severity,
    });
    setRules((prev) => prev.map((r) => (r.id === updated.id ? updated : r)));
    setEditingRuleId(null);
    setRuleDraft(null);
  };

  const handleSavePhishing = async () => {
    if (!phishingDraft || !editingPhishingId) return;
    const updated = await updatePhishingEntry(editingPhishingId, {
      domain: phishingDraft.domain,
      address: phishingDraft.address,
      type: phishingDraft.type,
      reportedBy: phishingDraft.reportedBy,
      status: phishingDraft.status,
    });
    setPhishing((prev) =>
      prev.map((p) => (p.id === updated.id ? updated : p))
    );
    setEditingPhishingId(null);
    setPhishingDraft(null);
  };

  const handleSaveContract = async () => {
    if (!contractDraft || !editingContractId) return;
    const updated = await updateContractWhitelistEntry(editingContractId, {
      address: contractDraft.address,
      name: contractDraft.name,
      chainId: contractDraft.chainId,
      status: contractDraft.status,
    });
    setContracts((prev) =>
      prev.map((c) => (c.id === updated.id ? updated : c))
    );
    setEditingContractId(null);
    setContractDraft(null);
  };

  const filteredRules = useMemo(
    () =>
      rules.filter(
        (r) =>
          !search ||
          r.name.toLowerCase().includes(search.toLowerCase()) ||
          r.description.toLowerCase().includes(search.toLowerCase()) ||
          r.type.toLowerCase().includes(search.toLowerCase())
      ),
    [rules, search]
  );

  const filteredPhishing = useMemo(
    () =>
      phishing.filter(
        (p) =>
          !search ||
          p.domain.toLowerCase().includes(search.toLowerCase()) ||
          p.address.toLowerCase().includes(search.toLowerCase()) ||
          p.type.toLowerCase().includes(search.toLowerCase())
      ),
    [phishing, search]
  );

  const filteredContracts = useMemo(
    () =>
      contracts.filter(
        (c) =>
          !search ||
          c.address.toLowerCase().includes(search.toLowerCase()) ||
          (c.name || '').toLowerCase().includes(search.toLowerCase()) ||
          (c.chainId || '').toLowerCase().includes(search.toLowerCase())
      ),
    [contracts, search]
  );

  const filteredAlerts = useMemo(
    () =>
      alerts.filter(
        (a) =>
          !search ||
          a.title.toLowerCase().includes(search.toLowerCase()) ||
          (a.description || '').toLowerCase().includes(search.toLowerCase())
      ),
    [alerts, search]
  );

  const addButtonLabel =
    activeTab === 'rules'
      ? '+ Add Rule'
      : activeTab === 'phishing'
        ? '+ Add Entry'
        : activeTab === 'contracts'
          ? '+ Add Contract'
          : activeTab === 'whitelist'
            ? '+ Add Address'
            : '';

  const handleAddClick = () => {
    if (activeTab === 'rules') setShowCreateRule((v) => !v);
    if (activeTab === 'phishing') setShowCreatePhishing((v) => !v);
    if (activeTab === 'contracts') setShowCreateContract((v) => !v);
    if (activeTab === 'whitelist') whitelistInputRef.current?.focus();
  };

  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 24,
        }}
      >
        <h2
          style={{
            margin: 0,
            fontSize: 22,
            color: 'var(--r-neutral-title-1, #192945)',
          }}
        >
          Security Management
        </h2>
        {activeTab !== 'alerts' && (
          <button
            onClick={handleAddClick}
            style={{
              padding: '8px 20px',
              borderRadius: 8,
              border: 'none',
              background: 'var(--r-blue-default, #4c65ff)',
              color: '#fff',
              fontSize: 13,
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            {addButtonLabel}
          </button>
        )}
      </div>

      <div style={{ display: 'flex', gap: 0, marginBottom: 20 }}>
        {(['rules', 'phishing', 'contracts', 'whitelist', 'alerts'] as const).map(
          (tab) => (
            <button
              key={tab}
              onClick={() => {
                setActiveTab(tab);
                setSearch('');
              }}
              style={{
                padding: '10px 24px',
                border: 'none',
                cursor: 'pointer',
                fontSize: 14,
                fontWeight: 500,
                background: activeTab === tab ? '#fff' : 'transparent',
                color:
                  activeTab === tab
                    ? 'var(--r-blue-default, #4c65ff)'
                    : 'var(--r-neutral-foot, #6a7587)',
                borderBottom:
                  activeTab === tab
                    ? '2px solid var(--r-blue-default, #4c65ff)'
                    : '2px solid transparent',
                borderRadius: '8px 8px 0 0',
              }}
            >
              {tab === 'rules'
                ? 'Security Rules'
                : tab === 'phishing'
                  ? 'Phishing Database'
                  : tab === 'contracts'
                    ? 'Contract Whitelist'
                    : tab === 'alerts'
                      ? 'Security Alerts'
                      : 'Address Whitelist'}
            </button>
          )
        )}
      </div>

      <div
        style={{
          display: 'flex',
          gap: 12,
          marginBottom: 20,
          padding: 16,
          background: '#fff',
          borderRadius: 12,
          boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
        }}
      >
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={
            activeTab === 'rules'
              ? 'Search rules...'
              : activeTab === 'phishing'
                ? 'Search by domain or address...'
                : activeTab === 'contracts'
                  ? 'Search by address, name, or chain...'
                  : activeTab === 'alerts'
                    ? 'Search alerts...'
                    : 'Search by address...'
          }
          style={{
            flex: 1,
            padding: '8px 14px',
            borderRadius: 8,
            border: '1px solid var(--r-neutral-line, #d9d9d9)',
            fontSize: 13,
          }}
        />
      </div>

      {activeTab === 'rules' && (
        <div>
          {showCreateRule && (
            <div
              style={{
                background: '#fff',
                borderRadius: 12,
                padding: 16,
                marginBottom: 16,
                boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
              }}
            >
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: '2fr 3fr 1fr 1fr',
                  gap: 12,
                }}
              >
                <input
                  style={inputStyle}
                  placeholder="Rule name"
                  value={newRule.name}
                  onChange={(e) =>
                    setNewRule((prev) => ({ ...prev, name: e.target.value }))
                  }
                />
                <input
                  style={inputStyle}
                  placeholder="Description"
                  value={newRule.description}
                  onChange={(e) =>
                    setNewRule((prev) => ({
                      ...prev,
                      description: e.target.value,
                    }))
                  }
                />
                <input
                  style={inputStyle}
                  placeholder="Type"
                  value={newRule.type}
                  onChange={(e) =>
                    setNewRule((prev) => ({ ...prev, type: e.target.value }))
                  }
                />
                <select
                  style={selectStyle}
                  value={newRule.severity}
                  onChange={(e) =>
                    setNewRule((prev) => ({
                      ...prev,
                      severity: e.target.value as SecuritySeverity,
                    }))
                  }
                >
                  {SEVERITY_OPTIONS.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </div>
              <div
                style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 12 }}
              >
                <button
                  onClick={() => setShowCreateRule(false)}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: '1px solid var(--r-neutral-line, #d9d9d9)',
                    background: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Cancel
                </button>
                <button
                  onClick={handleCreateRule}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: 'none',
                    background: 'var(--r-blue-default, #4c65ff)',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Create
                </button>
              </div>
            </div>
          )}

          <div
            style={{
              background: '#fff',
              borderRadius: 12,
              overflow: 'hidden',
              boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
            }}
          >
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr>
                  <th style={thStyle}>Rule</th>
                  <th style={thStyle}>Type</th>
                  <th style={thStyle}>Severity</th>
                  <th style={thStyle}>Triggers</th>
                  <th style={thStyle}>Last Triggered</th>
                  <th style={thStyle}>Enabled</th>
                  <th style={thStyle}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {rulesLoading ? (
                  <tr>
                    <td style={tdStyle} colSpan={7}>
                      Loading...
                    </td>
                  </tr>
                ) : (
                  filteredRules.map((rule) => {
                    const editing = editingRuleId === rule.id;
                    return (
                      <tr
                        key={rule.id}
                        onMouseEnter={(e) =>
                          (e.currentTarget.style.background = '#fafbfc')
                        }
                        onMouseLeave={(e) =>
                          (e.currentTarget.style.background = 'transparent')
                        }
                      >
                        <td style={tdStyle}>
                          {editing && ruleDraft ? (
                            <div style={{ display: 'grid', gap: 6 }}>
                              <input
                                style={inputStyle}
                                value={ruleDraft.name}
                                onChange={(e) =>
                                  setRuleDraft({
                                    ...ruleDraft,
                                    name: e.target.value,
                                  })
                                }
                              />
                              <input
                                style={inputStyle}
                                value={ruleDraft.description}
                                onChange={(e) =>
                                  setRuleDraft({
                                    ...ruleDraft,
                                    description: e.target.value,
                                  })
                                }
                              />
                            </div>
                          ) : (
                            <>
                              <div
                                style={{
                                  fontWeight: 600,
                                  color: 'var(--r-neutral-title-1, #192945)',
                                  marginBottom: 2,
                                }}
                              >
                                {rule.name}
                              </div>
                              <div
                                style={{
                                  fontSize: 11,
                                  color: 'var(--r-neutral-foot, #8c95a6)',
                                }}
                              >
                                {rule.description}
                              </div>
                            </>
                          )}
                        </td>
                        <td style={tdStyle}>
                          {editing && ruleDraft ? (
                            <input
                              style={inputStyle}
                              value={ruleDraft.type}
                              onChange={(e) =>
                                setRuleDraft({
                                  ...ruleDraft,
                                  type: e.target.value,
                                })
                              }
                            />
                          ) : (
                            <span
                              style={{
                                padding: '2px 8px',
                                borderRadius: 4,
                                fontSize: 11,
                                background: 'var(--r-neutral-bg-3, #f0f2f5)',
                                color: 'var(--r-neutral-body, #3e495e)',
                              }}
                            >
                              {rule.type}
                            </span>
                          )}
                        </td>
                        <td style={tdStyle}>
                          {editing && ruleDraft ? (
                            <select
                              style={selectStyle}
                              value={ruleDraft.severity}
                              onChange={(e) =>
                                setRuleDraft({
                                  ...ruleDraft,
                                  severity: e.target.value as SecuritySeverity,
                                })
                              }
                            >
                              {SEVERITY_OPTIONS.map((s) => (
                                <option key={s} value={s}>
                                  {s}
                                </option>
                              ))}
                            </select>
                          ) : (
                            <span
                              style={{
                                padding: '3px 10px',
                                borderRadius: 12,
                                fontSize: 11,
                                fontWeight: 600,
                                ...SEVERITY_STYLES[rule.severity],
                              }}
                            >
                              {rule.severity}
                            </span>
                          )}
                        </td>
                        <td style={{ ...tdStyle, fontWeight: 600 }}>
                          {rule.triggers.toLocaleString()}
                        </td>
                        <td style={{ ...tdStyle, fontSize: 12, color: 'var(--r-neutral-foot, #6a7587)' }}>
                          {rule.lastTriggered || '-'}
                        </td>
                        <td style={tdStyle}>
                          <button
                            onClick={() => handleToggleRule(rule)}
                            style={{
                              width: 40,
                              height: 22,
                              borderRadius: 11,
                              border: 'none',
                              cursor: 'pointer',
                              background: rule.enabled
                                ? 'var(--r-blue-default, #4c65ff)'
                                : '#d9d9d9',
                              position: 'relative',
                              transition: 'background 200ms',
                            }}
                          >
                            <span
                              style={{
                                position: 'absolute',
                                top: 2,
                                width: 18,
                                height: 18,
                                borderRadius: '50%',
                                background: '#fff',
                                transition: 'left 200ms',
                                left: rule.enabled ? 20 : 2,
                                boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
                              }}
                            />
                          </button>
                        </td>
                        <td style={tdStyle}>
                          {editing ? (
                            <div style={{ display: 'flex', gap: 6 }}>
                              <button
                                onClick={handleSaveRule}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: 'none',
                                  background: 'var(--r-blue-default, #4c65ff)',
                                  color: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                }}
                              >
                                Save
                              </button>
                              <button
                                onClick={() => {
                                  setEditingRuleId(null);
                                  setRuleDraft(null);
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid var(--r-neutral-line, #d9d9d9)',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                }}
                              >
                                Cancel
                              </button>
                            </div>
                          ) : (
                            <div style={{ display: 'flex', gap: 6 }}>
                              <button
                                onClick={() => {
                                  setEditingRuleId(rule.id);
                                  setRuleDraft(rule);
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid var(--r-neutral-line, #d9d9d9)',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                  color: 'var(--r-blue-default, #4c65ff)',
                                }}
                              >
                                Edit
                              </button>
                              <button
                                onClick={async () => {
                                  await deleteSecurityRule(rule.id);
                                  setRules((prev) =>
                                    prev.filter((r) => r.id !== rule.id)
                                  );
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid #ffccc7',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                  color: '#cf1322',
                                }}
                              >
                                Delete
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
            <div
              style={{
                padding: '12px 16px',
                borderTop: '1px solid var(--r-neutral-line, #f0f0f0)',
                fontSize: 13,
                color: 'var(--r-neutral-foot, #6a7587)',
              }}
            >
              Showing {filteredRules.length} of {rules.length} rules
            </div>
          </div>
        </div>
      )}

      {activeTab === 'phishing' && (
        <div>
          {showCreatePhishing && (
            <div
              style={{
                background: '#fff',
                borderRadius: 12,
                padding: 16,
                marginBottom: 16,
                boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
              }}
            >
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: '2fr 2fr 1fr 1fr 1fr',
                  gap: 12,
                }}
              >
                <input
                  style={inputStyle}
                  placeholder="Domain"
                  value={newPhishing.domain}
                  onChange={(e) =>
                    setNewPhishing((prev) => ({ ...prev, domain: e.target.value }))
                  }
                />
                <input
                  style={inputStyle}
                  placeholder="Address"
                  value={newPhishing.address}
                  onChange={(e) =>
                    setNewPhishing((prev) => ({ ...prev, address: e.target.value }))
                  }
                />
                <input
                  style={inputStyle}
                  placeholder="Type"
                  value={newPhishing.type}
                  onChange={(e) =>
                    setNewPhishing((prev) => ({ ...prev, type: e.target.value }))
                  }
                />
                <input
                  style={inputStyle}
                  placeholder="Reported by"
                  value={newPhishing.reportedBy}
                  onChange={(e) =>
                    setNewPhishing((prev) => ({
                      ...prev,
                      reportedBy: e.target.value,
                    }))
                  }
                />
                <select
                  style={selectStyle}
                  value={newPhishing.status}
                  onChange={(e) =>
                    setNewPhishing((prev) => ({ ...prev, status: e.target.value }))
                  }
                >
                  <option value="confirmed">confirmed</option>
                  <option value="pending">pending</option>
                </select>
              </div>
              <div
                style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 12 }}
              >
                <button
                  onClick={() => setShowCreatePhishing(false)}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: '1px solid var(--r-neutral-line, #d9d9d9)',
                    background: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Cancel
                </button>
                <button
                  onClick={handleCreatePhishing}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: 'none',
                    background: 'var(--r-blue-default, #4c65ff)',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Create
                </button>
              </div>
            </div>
          )}

          <div
            style={{
              background: '#fff',
              borderRadius: 12,
              overflow: 'hidden',
              boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
            }}
          >
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr>
                  <th style={thStyle}>Domain</th>
                  <th style={thStyle}>Address</th>
                  <th style={thStyle}>Type</th>
                  <th style={thStyle}>Reported By</th>
                  <th style={thStyle}>Added</th>
                  <th style={thStyle}>Status</th>
                  <th style={thStyle}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {phishingLoading ? (
                  <tr>
                    <td style={tdStyle} colSpan={7}>
                      Loading...
                    </td>
                  </tr>
                ) : (
                  filteredPhishing.map((entry) => {
                    const editing = editingPhishingId === entry.id;
                    return (
                      <tr
                        key={entry.id}
                        onMouseEnter={(e) =>
                          (e.currentTarget.style.background = '#fafbfc')
                        }
                        onMouseLeave={(e) =>
                          (e.currentTarget.style.background = 'transparent')
                        }
                      >
                        <td style={{ ...tdStyle, fontWeight: 600, color: 'var(--r-red-default, #cf1322)' }}>
                          {editing && phishingDraft ? (
                            <input
                              style={inputStyle}
                              value={phishingDraft.domain}
                              onChange={(e) =>
                                setPhishingDraft({
                                  ...phishingDraft,
                                  domain: e.target.value,
                                })
                              }
                            />
                          ) : (
                            entry.domain
                          )}
                        </td>
                        <td style={{ ...tdStyle, fontFamily: 'monospace', fontSize: 12 }}>
                          {editing && phishingDraft ? (
                            <input
                              style={inputStyle}
                              value={phishingDraft.address}
                              onChange={(e) =>
                                setPhishingDraft({
                                  ...phishingDraft,
                                  address: e.target.value,
                                })
                              }
                            />
                          ) : (
                            entry.address
                          )}
                        </td>
                        <td style={tdStyle}>
                          {editing && phishingDraft ? (
                            <input
                              style={inputStyle}
                              value={phishingDraft.type}
                              onChange={(e) =>
                                setPhishingDraft({
                                  ...phishingDraft,
                                  type: e.target.value,
                                })
                              }
                            />
                          ) : (
                            <span
                              style={{
                                padding: '2px 8px',
                                borderRadius: 4,
                                fontSize: 11,
                                background: 'var(--r-neutral-bg-3, #f0f2f5)',
                                color: 'var(--r-neutral-body, #3e495e)',
                              }}
                            >
                              {entry.type.replace('_', ' ')}
                            </span>
                          )}
                        </td>
                        <td style={tdStyle}>
                          {editing && phishingDraft ? (
                            <input
                              style={inputStyle}
                              value={phishingDraft.reportedBy}
                              onChange={(e) =>
                                setPhishingDraft({
                                  ...phishingDraft,
                                  reportedBy: e.target.value,
                                })
                              }
                            />
                          ) : (
                            entry.reportedBy
                          )}
                        </td>
                        <td
                          style={{
                            ...tdStyle,
                            fontSize: 12,
                            color: 'var(--r-neutral-foot, #6a7587)',
                          }}
                        >
                          {entry.addedDate}
                        </td>
                        <td style={tdStyle}>
                          {editing && phishingDraft ? (
                            <select
                              style={selectStyle}
                              value={phishingDraft.status}
                              onChange={(e) =>
                                setPhishingDraft({
                                  ...phishingDraft,
                                  status: e.target.value as 'confirmed' | 'pending',
                                })
                              }
                            >
                              <option value="confirmed">confirmed</option>
                              <option value="pending">pending</option>
                            </select>
                          ) : (
                            <span
                              style={{
                                padding: '3px 10px',
                                borderRadius: 12,
                                fontSize: 11,
                                fontWeight: 600,
                                ...STATUS_STYLES[entry.status],
                              }}
                            >
                              {entry.status}
                            </span>
                          )}
                        </td>
                        <td style={tdStyle}>
                          {editing ? (
                            <div style={{ display: 'flex', gap: 6 }}>
                              <button
                                onClick={handleSavePhishing}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: 'none',
                                  background: 'var(--r-blue-default, #4c65ff)',
                                  color: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                }}
                              >
                                Save
                              </button>
                              <button
                                onClick={() => {
                                  setEditingPhishingId(null);
                                  setPhishingDraft(null);
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid var(--r-neutral-line, #d9d9d9)',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                }}
                              >
                                Cancel
                              </button>
                            </div>
                          ) : (
                            <div style={{ display: 'flex', gap: 6 }}>
                              <button
                                onClick={() => {
                                  setEditingPhishingId(entry.id);
                                  setPhishingDraft(entry);
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid var(--r-neutral-line, #d9d9d9)',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                  color: 'var(--r-blue-default, #4c65ff)',
                                }}
                              >
                                Edit
                              </button>
                              <button
                                onClick={async () => {
                                  await deletePhishingEntry(entry.id);
                                  setPhishing((prev) =>
                                    prev.filter((p) => p.id !== entry.id)
                                  );
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid #ffccc7',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                  color: '#cf1322',
                                }}
                              >
                                Remove
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
            <div
              style={{
                padding: '12px 16px',
                borderTop: '1px solid var(--r-neutral-line, #f0f0f0)',
                fontSize: 13,
                color: 'var(--r-neutral-foot, #6a7587)',
              }}
            >
              Showing {filteredPhishing.length} of {phishing.length} entries
            </div>
          </div>
        </div>
      )}

      {activeTab === 'contracts' && (
        <div>
          {showCreateContract && (
            <div
              style={{
                background: '#fff',
                borderRadius: 12,
                padding: 16,
                marginBottom: 16,
                boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
              }}
            >
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: '2fr 2fr 1fr 1fr',
                  gap: 12,
                }}
              >
                <input
                  style={inputStyle}
                  placeholder="Contract address"
                  value={newContract.address}
                  onChange={(e) =>
                    setNewContract((prev) => ({ ...prev, address: e.target.value }))
                  }
                />
                <input
                  style={inputStyle}
                  placeholder="Name (optional)"
                  value={newContract.name}
                  onChange={(e) =>
                    setNewContract((prev) => ({ ...prev, name: e.target.value }))
                  }
                />
                <input
                  style={inputStyle}
                  placeholder="Chain ID"
                  value={newContract.chainId}
                  onChange={(e) =>
                    setNewContract((prev) => ({ ...prev, chainId: e.target.value }))
                  }
                />
                <select
                  style={selectStyle}
                  value={newContract.status}
                  onChange={(e) =>
                    setNewContract((prev) => ({ ...prev, status: e.target.value }))
                  }
                >
                  <option value="active">active</option>
                  <option value="disabled">disabled</option>
                </select>
              </div>
              <div
                style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 12 }}
              >
                <button
                  onClick={() => setShowCreateContract(false)}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: '1px solid var(--r-neutral-line, #d9d9d9)',
                    background: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Cancel
                </button>
                <button
                  onClick={handleCreateContract}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: 'none',
                    background: 'var(--r-blue-default, #4c65ff)',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Create
                </button>
              </div>
            </div>
          )}

          <div
            style={{
              background: '#fff',
              borderRadius: 12,
              overflow: 'hidden',
              boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
            }}
          >
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr>
                  <th style={thStyle}>Address</th>
                  <th style={thStyle}>Name</th>
                  <th style={thStyle}>Chain</th>
                  <th style={thStyle}>Added</th>
                  <th style={thStyle}>Status</th>
                  <th style={thStyle}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {contractsLoading ? (
                  <tr>
                    <td style={tdStyle} colSpan={6}>
                      Loading...
                    </td>
                  </tr>
                ) : (
                  filteredContracts.map((entry) => {
                    const editing = editingContractId === entry.id;
                    return (
                      <tr
                        key={entry.id}
                        onMouseEnter={(e) =>
                          (e.currentTarget.style.background = '#fafbfc')
                        }
                        onMouseLeave={(e) =>
                          (e.currentTarget.style.background = 'transparent')
                        }
                      >
                        <td style={{ ...tdStyle, fontFamily: 'monospace', fontSize: 12 }}>
                          {editing && contractDraft ? (
                            <input
                              style={inputStyle}
                              value={contractDraft.address}
                              onChange={(e) =>
                                setContractDraft({
                                  ...contractDraft,
                                  address: e.target.value,
                                })
                              }
                            />
                          ) : (
                            entry.address
                          )}
                        </td>
                        <td style={tdStyle}>
                          {editing && contractDraft ? (
                            <input
                              style={inputStyle}
                              value={contractDraft.name || ''}
                              onChange={(e) =>
                                setContractDraft({
                                  ...contractDraft,
                                  name: e.target.value,
                                })
                              }
                            />
                          ) : (
                            entry.name || '-'
                          )}
                        </td>
                        <td style={tdStyle}>
                          {editing && contractDraft ? (
                            <input
                              style={inputStyle}
                              value={contractDraft.chainId || ''}
                              onChange={(e) =>
                                setContractDraft({
                                  ...contractDraft,
                                  chainId: e.target.value,
                                })
                              }
                            />
                          ) : (
                            entry.chainId || '-'
                          )}
                        </td>
                        <td
                          style={{
                            ...tdStyle,
                            fontSize: 12,
                            color: 'var(--r-neutral-foot, #6a7587)',
                          }}
                        >
                          {entry.addedDate}
                        </td>
                        <td style={tdStyle}>
                          {editing && contractDraft ? (
                            <select
                              style={selectStyle}
                              value={contractDraft.status}
                              onChange={(e) =>
                                setContractDraft({
                                  ...contractDraft,
                                  status: e.target.value as 'active' | 'disabled',
                                })
                              }
                            >
                              <option value="active">active</option>
                              <option value="disabled">disabled</option>
                            </select>
                          ) : (
                            <span
                              style={{
                                padding: '3px 10px',
                                borderRadius: 12,
                                fontSize: 11,
                                fontWeight: 600,
                                ...STATUS_STYLES[entry.status],
                              }}
                            >
                              {entry.status}
                            </span>
                          )}
                        </td>
                        <td style={tdStyle}>
                          {editing ? (
                            <div style={{ display: 'flex', gap: 6 }}>
                              <button
                                onClick={handleSaveContract}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: 'none',
                                  background: 'var(--r-blue-default, #4c65ff)',
                                  color: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                }}
                              >
                                Save
                              </button>
                              <button
                                onClick={() => {
                                  setEditingContractId(null);
                                  setContractDraft(null);
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid var(--r-neutral-line, #d9d9d9)',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                }}
                              >
                                Cancel
                              </button>
                            </div>
                          ) : (
                            <div style={{ display: 'flex', gap: 6 }}>
                              <button
                                onClick={() => {
                                  setEditingContractId(entry.id);
                                  setContractDraft(entry);
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid var(--r-neutral-line, #d9d9d9)',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                  color: 'var(--r-blue-default, #4c65ff)',
                                }}
                              >
                                Edit
                              </button>
                              <button
                                onClick={async () => {
                                  await deleteContractWhitelistEntry(entry.id);
                                  setContracts((prev) =>
                                    prev.filter((c) => c.id !== entry.id)
                                  );
                                }}
                                style={{
                                  padding: '4px 10px',
                                  borderRadius: 6,
                                  border: '1px solid #ffccc7',
                                  background: '#fff',
                                  fontSize: 11,
                                  cursor: 'pointer',
                                  color: '#cf1322',
                                }}
                              >
                                Remove
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
            <div
              style={{
                padding: '12px 16px',
                borderTop: '1px solid var(--r-neutral-line, #f0f0f0)',
                fontSize: 13,
                color: 'var(--r-neutral-foot, #6a7587)',
              }}
            >
              Showing {filteredContracts.length} of {contracts.length} contracts
            </div>
          </div>
        </div>
      )}

      {activeTab === 'alerts' && (
        <div
          style={{
            background: '#fff',
            borderRadius: 12,
            overflow: 'hidden',
            boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
          }}
        >
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr>
                <th style={thStyle}>Alert</th>
                <th style={thStyle}>Level</th>
                <th style={thStyle}>Created</th>
                <th style={thStyle}>Status</th>
                <th style={thStyle}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {alertsLoading ? (
                <tr>
                  <td style={tdStyle} colSpan={5}>
                    Loading...
                  </td>
                </tr>
              ) : (
                filteredAlerts.map((alert) => (
                  <tr
                    key={alert.id}
                    onMouseEnter={(e) =>
                      (e.currentTarget.style.background = '#fafbfc')
                    }
                    onMouseLeave={(e) =>
                      (e.currentTarget.style.background = 'transparent')
                    }
                  >
                    <td style={tdStyle}>
                      <div
                        style={{
                          fontWeight: 600,
                          color: 'var(--r-neutral-title-1, #192945)',
                        }}
                      >
                        {alert.title}
                      </div>
                      {alert.description && (
                        <div
                          style={{
                            fontSize: 11,
                            color: 'var(--r-neutral-foot, #8c95a6)',
                          }}
                        >
                          {alert.description}
                        </div>
                      )}
                    </td>
                    <td style={tdStyle}>
                      <span
                        style={{
                          padding: '3px 10px',
                          borderRadius: 12,
                          fontSize: 11,
                          fontWeight: 600,
                          ...SEVERITY_STYLES[alert.level],
                        }}
                      >
                        {alert.level}
                      </span>
                    </td>
                    <td
                      style={{
                        ...tdStyle,
                        fontSize: 12,
                        color: 'var(--r-neutral-foot, #6a7587)',
                      }}
                    >
                      {alert.createdAt}
                    </td>
                    <td style={tdStyle}>
                      <span
                        style={{
                          padding: '3px 10px',
                          borderRadius: 12,
                          fontSize: 11,
                          fontWeight: 600,
                          ...STATUS_STYLES[alert.status],
                        }}
                      >
                        {alert.status}
                      </span>
                    </td>
                    <td style={tdStyle}>
                      {alert.status === 'open' ? (
                        <button
                          onClick={async () => {
                            const updated = await updateSecurityAlert(alert.id, {
                              status: 'resolved',
                            });
                            setAlerts((prev) =>
                              prev.map((a) => (a.id === updated.id ? updated : a))
                            );
                          }}
                          style={{
                            padding: '4px 10px',
                            borderRadius: 6,
                            border: '1px solid var(--r-neutral-line, #d9d9d9)',
                            background: '#fff',
                            fontSize: 11,
                            cursor: 'pointer',
                            color: 'var(--r-blue-default, #4c65ff)',
                          }}
                        >
                          Resolve
                        </button>
                      ) : (
                        '-'
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          <div
            style={{
              padding: '12px 16px',
              borderTop: '1px solid var(--r-neutral-line, #f0f0f0)',
              fontSize: 13,
              color: 'var(--r-neutral-foot, #6a7587)',
            }}
          >
            Showing {filteredAlerts.length} of {alerts.length} alerts
          </div>
        </div>
      )}

      {activeTab === 'whitelist' && (
        <div
          style={{
            background: '#fff',
            borderRadius: 12,
            overflow: 'hidden',
            boxShadow: 'var(--rabby-shadow-sm, 0 1px 3px rgba(0,0,0,0.06))',
          }}
        >
          <div
            style={{
              padding: 16,
              borderBottom: '1px solid var(--r-neutral-line, #f0f0f0)',
              display: 'flex',
              gap: 8,
            }}
          >
            <input
              ref={whitelistInputRef}
              value={newWhitelistAddr}
              onChange={(e) => setNewWhitelistAddr(e.target.value)}
              placeholder="Enter Ethereum address (0x...)"
              style={{
                flex: 1,
                padding: '8px 14px',
                borderRadius: 8,
                border: '1px solid var(--r-neutral-line, #d9d9d9)',
                fontSize: 13,
              }}
              onKeyDown={(e) => e.key === 'Enter' && handleAddWhitelist()}
            />
            <button
              onClick={handleAddWhitelist}
              style={{
                padding: '8px 20px',
                borderRadius: 8,
                border: 'none',
                background: 'var(--r-blue-default, #4c65ff)',
                color: '#fff',
                fontSize: 13,
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Add
            </button>
          </div>
          {whitelistLoading ? (
            <div
              style={{
                padding: 24,
                textAlign: 'center',
                color: 'var(--r-neutral-foot, #6a7587)',
              }}
            >
              Loading...
            </div>
          ) : whitelistAddresses.length === 0 ? (
            <div
              style={{
                padding: 24,
                textAlign: 'center',
                color: 'var(--r-neutral-foot, #6a7587)',
              }}
            >
              No addresses in whitelist
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr>
                  <th style={thStyle}>Address</th>
                  <th style={{ ...thStyle, width: 100 }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {whitelistAddresses.map((addr) => (
                  <tr
                    key={addr}
                    onMouseEnter={(e) =>
                      (e.currentTarget.style.background = '#fafbfc')
                    }
                    onMouseLeave={(e) =>
                      (e.currentTarget.style.background = 'transparent')
                    }
                  >
                    <td style={{ ...tdStyle, fontFamily: 'monospace' }}>{addr}</td>
                    <td style={tdStyle}>
                      <button
                        onClick={() => handleRemoveWhitelist(addr)}
                        style={{
                          padding: '4px 10px',
                          borderRadius: 6,
                          border: '1px solid #ffccc7',
                          background: '#fff',
                          fontSize: 11,
                          cursor: 'pointer',
                          color: '#cf1322',
                        }}
                      >
                        Remove
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <div
            style={{
              padding: '12px 16px',
              borderTop: '1px solid var(--r-neutral-line, #f0f0f0)',
              fontSize: 13,
              color: 'var(--r-neutral-foot, #6a7587)',
            }}
          >
            {whitelistAddresses.length} address(es) in whitelist
          </div>
        </div>
      )}
    </div>
  );
}
