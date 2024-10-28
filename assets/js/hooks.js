const TimeZoneHook = {
    mounted() {
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      this.pushEvent("set_timezone", { timezone: timezone });
    }
  }

  export default {
    TimeZoneHook
  };
