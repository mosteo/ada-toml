with Ada.Text_IO;

with TOML;

procedure Main is
   Value : constant TOML.TOML_Value := TOML.Load_File ("example.toml").Value;
begin
   Value.Unset ("array");
   Ada.Text_IO.Put_Line (Value.Dump_As_String);
end Main;
