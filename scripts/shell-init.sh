# Lido no início de cada shell do terminal do Hermes neste perfil (terminal.shell_init_files no config.yaml).
# Kit do Torriani: a chave de imagem viaja da shell que abriu o kit até aqui com o nome neutro UNNISEND_IMAGEM_OR
# (o Hermes não deixa OPENROUTER_API_KEY atravessar). Aqui ela vira o nome que a política 1.1 exige, e o neutro some.
if [ -n "${UNNISEND_IMAGEM_OR:-}" ]; then
  export OPENROUTER_API_KEY="$UNNISEND_IMAGEM_OR"
  unset UNNISEND_IMAGEM_OR
fi
