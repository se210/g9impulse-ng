  --Example instantiation for system 'gpu'
  gpu_inst : gpu
    port map(
      out_port_from_the_LEDs => out_port_from_the_LEDs,
      clk_0 => clk_0,
      in_port_to_the_Switches => in_port_to_the_Switches,
      reset_n => reset_n
    );


