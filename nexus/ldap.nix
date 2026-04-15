{ config, pkgs, ... }:

{
  # SSSD für LDAP Authentifizierung
  services.sssd = {
    enable = true;
    config = ''
      [sssd]
      domains = sternenhof.space
      services = nss, pam

      [domain/sternenhof.space]
      id_provider = ldap
      auth_provider = ldap
      ldap_uri = ldap://darwin26.sternenhof.space:389
      ldap_search_base = ou=users,dc=sternenhof,dc=space
      ldap_bind_dn = cn=admin,dc=sternenhof,dc=space
      ldap_bind_authtok_type = password
      ldap_user_object_class = inetOrgPerson
      ldap_user_name = uid
      enumerate = true
      cache_credentials = true
    '';
  };

  # Home-Ordner automatisch erstellen beim ersten Login
  security.pam.services.sddm.makeHomeDir = true;
  security.pam.makeHomeDir.umask = "0077";
}
